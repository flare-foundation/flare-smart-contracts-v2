// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IDiamond} from "../../contracts/diamond/interfaces/IDiamond.sol";
import {IDiamondCut} from "../../contracts/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../contracts/diamond/interfaces/IDiamondLoupe.sol";

// solhint-disable no-console
contract ExecuteTeeManagerDiamondCut is Script {
    using stdJson for string;

    string private network;
    string private configFileName;

    function run(
        string calldata _configFileName
    )
        external
    {
        string memory deployedContractsFile = "deployment/deploys/";
        uint256 chainId = block.chainid;
        configFileName = _configFileName;

        if (chainId == 14) {
            network = "flare";
        } else if (chainId == 19) {
            network = "songbird";
        } else if (chainId == 16) {
            network = "coston";
        } else if (chainId == 114) {
            network = "coston2";
        } else {
            network = "scdev";
        }
        deployedContractsFile = string.concat(deployedContractsFile, network, ".json");
        console2.log(string.concat("NETWORK: ", network));

        string memory configFilePath = string.concat(
            "deployment/cuts/", network, "/", _configFileName, ".json"
        );
        string memory json = vm.readFile(configFilePath);

        // read execute flag from JSON config
        bool execute = false;
        bytes memory rawExecute = json.parseRaw(".execute");
        if (rawExecute.length > 0) {
            execute = abi.decode(rawExecute, (bool));
        }

        address diamond = abi.decode(json.parseRaw(".diamond"), (address));
        string[] memory facetNames = abi.decode(json.parseRaw(".facets"), (string[]));

        address[] memory facetAddrs = new address[](facetNames.length);
        // deploy facets
        vm.startBroadcast();
        for (uint256 i = 0; i < facetNames.length; i++) {
            // check deployed facets; if bytecode matches, reuse; else deploy new
            address candidate = _findDeployedAddressFromFile(deployedContractsFile, facetNames[i]);
            string memory artifactPath = string.concat(
                "artifacts-forge/", facetNames[i], ".sol/", facetNames[i], ".json"
            );
            console2.log("Checking facet:", facetNames[i], "candidate address:", candidate);
            if (_deployedCodeMatches(candidate, artifactPath)) {
                console2.log("Reusing deployed facet at:", candidate);
                facetAddrs[i] = candidate;
            } else {
                console2.log("Deploying facet:", facetNames[i]);
                facetAddrs[i] = _deployFacet(facetNames[i]);
                // always update facet address in deploys file
                _updateAddressInFile(
                    deployedContractsFile,
                    facetNames[i],
                    facetAddrs[i]
                );
            }
        }

        // if init contract is not already included in facets, deploy it separately
        address initAddr = address(0);
        bytes memory rawInit = json.parseRaw(".init");
        if (rawInit.length > 0) {
            bytes memory rawInitName = json.parseRaw(".init.contract");
            require(rawInitName.length > 0, "init.contract is required if init object exists");
            string memory initName = abi.decode(rawInitName, (string));
            require(bytes(initName).length > 0, "init.contract cannot be empty");
            bool foundInFacets = false;
            for (uint256 i = 0; i < facetNames.length; i++) {
                if (_stringEq(facetNames[i], initName)) {
                    initAddr = facetAddrs[i];
                    foundInFacets = true;
                    break;
                }
            }
            if (!foundInFacets) {
                // try reuse from deploys if code matches; else deploy from artifact
                address candidate = _findDeployedAddressFromFile(
                    deployedContractsFile, initName
                );
                string memory artifactPath = string.concat(
                    "artifacts-forge/", initName, ".sol/", initName, ".json"
                );
                if (_deployedCodeMatches(candidate, artifactPath)) {
                    initAddr = candidate;
                } else {
                    initAddr = _deployFacet(initName);
                    _updateAddressInFile(
                        deployedContractsFile,
                        initName,
                        initAddr
                    );
                }
            }
        }
        vm.stopBroadcast();

        _testWithConfig(
            diamond,
            facetAddrs,
            facetNames,
            initAddr,
            execute,
            configFilePath
        );
    }

    function _testWithConfig(
        address _diamond,
        address[] memory _facetAddrs,
        string[] memory _facetNames,
        address _initAddress,
        bool _execute,
        string memory _configPath
    )
        internal
    {
        // Create output directory if it doesn't exist
        string[] memory mkdirCmd = new string[](3);
        mkdirCmd[0] = "mkdir";
        mkdirCmd[1] = "-p";
        mkdirCmd[2] = string.concat("deployment/output-internal/", network);
        vm.ffi(mkdirCmd);

        // 1. read facets from diamond loupe
        IDiamondLoupe.Facet[] memory loupeFacets = IDiamondLoupe(_diamond).facets();
        // 2. write minimal text inputs for TS script
        string memory facetsPath = string.concat(
            "deployment/", "output-internal/", network, "/", "facets-", configFileName, ".txt"
        );
        string memory loupePath = string.concat(
            "deployment/", "output-internal/", network, "/", "loupe-", configFileName, ".txt"
        );
        _writeFacetsFile(facetsPath, _facetAddrs, _facetNames);
        _writeLoupeFile(loupePath, loupeFacets);
        // 3. call TS script via tsx which outputs ABI-encoded bytes
        bool hasInitAddr = _initAddress != address(0);
        uint256 len =
            3 /*npx tsx script*/ +
            2 /*diamond*/ +
            2 /*facets-file*/ +
            2 /*loupe-file*/ +
            2 /*config*/ +
            (hasInitAddr ? 2 : 0);
        string[] memory cmd = new string[](len);
        uint256 k = 0;
        cmd[k++] = "npx"; cmd[k++] = "tsx"; cmd[k++] = "deployment/utils/build-cut.ts";
        cmd[k++] = "--diamond"; cmd[k++] = _addrToString(_diamond);
        cmd[k++] = "--facets-file"; cmd[k++] = facetsPath;
        cmd[k++] = "--loupe-file"; cmd[k++] = loupePath;
        if (hasInitAddr) {
            cmd[k++] = "--init-address"; cmd[k++] = _addrToString(_initAddress);
        }
        cmd[k++] = "--config"; cmd[k++] = _configPath;
        bytes memory out = vm.ffi(cmd);
        // 4. decode ABI-encoded result
        (
            IDiamond.FacetCut[] memory cuts,
            address initAddr,
            bytes memory initData
        ) = abi.decode(out, (IDiamond.FacetCut[], address, bytes));
        // 5. execute or log
        console2.log("---- DIAMOND CUT DATA: ----");
        console2.log("diamond address:", _diamond);
        console2.log("number of cuts:", cuts.length);
        for (uint256 i = 0; i < cuts.length; i++) {
            console2.log(string(abi.encodePacked("cuts[", vm.toString(i), "]:")));
            console2.log("  facetAddress:", cuts[i].facetAddress);
            console2.log("  action:", _actionName(cuts[i].action));
            console2.log("  functionSelectors:");
            for (uint256 j = 0; j < cuts[i].functionSelectors.length; j++) {
                console2.log(string(
                    abi.encodePacked(
                        "    [", vm.toString(j), "]: 0x", _toHex(cuts[i].functionSelectors[j])
                    )
                ));
            }
        }
        console2.log("init data:");
        console2.log("  init address:", initAddr);
        console2.log(string(abi.encodePacked("  init calldata: 0x", _toHexBytes(initData))));
        bytes memory callData = abi.encodeWithSelector(
            IDiamondCut.diamondCut.selector, cuts, initAddr, initData
        );
        console2.log(string(abi.encodePacked("diamondCut calldata: 0x", _toHexBytes(callData))));
        if (_execute) {
            vm.startBroadcast();
            IDiamondCut(_diamond).diamondCut(cuts, initAddr, initData);
            vm.stopBroadcast();
        } else {
            // write ABI-encoded result to output file
            string memory encodedPath = string.concat(
                "deployment/", "output-internal/", network, "/",
                "diamond-cut-encoded-", configFileName, ".bin"
            );
            vm.writeFileBinary(encodedPath, out);
            // path for formatted JSON output
            string memory outputPath = string.concat(
                "deployment/", "output-internal/", network, "/",
                "decoded-", configFileName, ".json"
            );
            // call format-cut.ts via FFI
            string[] memory prettyCmd = new string[](7);
            prettyCmd[0] = "npx";
            prettyCmd[1] = "tsx";
            prettyCmd[2] = "deployment/utils/format-cut.ts";
            prettyCmd[3] = "--encoded-path";
            prettyCmd[4] = encodedPath;
            prettyCmd[5] = "--output-path";
            prettyCmd[6] = outputPath;
            vm.ffi(prettyCmd);
            string memory prettyJson = vm.readFile(outputPath);
            console2.log("---- Diamond cut not executed. Data for manual execution: ----");
            console2.log("decoded tuples (JSON):");
            console2.log(prettyJson);
            console2.log("---------------------------------------");
        }
    }

    function _writeFacetsFile(
        string memory _path,
        address[] memory _facetAddrs,
        string[] memory _facetNames
    )
        internal
    {
        string memory data = "";
        for (uint256 i = 0; i < _facetAddrs.length; i++) {
            // address|contractName
            data = string(abi.encodePacked(
                data, _addrToString(_facetAddrs[i]), "|", _facetNames[i], "\n"
            ));
        }
        vm.writeFile(_path, data);
    }

    function _writeLoupeFile(
        string memory _path,
        IDiamondLoupe.Facet[] memory _loupeFacets
    )
        internal
    {
        // facetAddress|sel1,sel2,sel3
        string memory data = "";
        for (uint256 i = 0; i < _loupeFacets.length; i++) {
            data = string(abi.encodePacked(
                data, _addrToString(_loupeFacets[i].facetAddress), "|"
            ));
            for (uint256 j = 0; j < _loupeFacets[i].functionSelectors.length; j++) {
                data = string(abi.encodePacked(
                    data,
                    _bytesToString(abi.encodePacked(_loupeFacets[i].functionSelectors[j])),
                    j + 1 == _loupeFacets[i].functionSelectors.length ? "" : ","
                ));
            }
            data = string(abi.encodePacked(data, "\n"));
        }
        vm.writeFile(_path, data);
    }

    function _updateAddressInFile(
        string memory _contractsFilePath,
        string memory _facetName,
        address _facetAddress
    )
        internal
    {
        string[] memory cmd = new string[](6);
        cmd[0] = "npx";
        cmd[1] = "tsx";
        cmd[2] = "deployment/utils/update-facet-address.ts";
        cmd[3] = _contractsFilePath;
        cmd[4] = _facetName;
        cmd[5] = _addrToString(_facetAddress);
        vm.ffi(cmd);
    }

    function _deployFacet(
        string memory _name
    )
        internal
        returns (address _deployed)
    {
        string memory artifactPath = string.concat(
            "artifacts-forge/", _name, ".sol/", _name, ".json"
        );
        bytes memory byteCode = vm.getCode(artifactPath);

        if (byteCode.length > 0) {
            //solhint-disable-next-line no-inline-assembly
            assembly {
                _deployed := create(0, add(byteCode, 0x20), mload(byteCode))
                if iszero(_deployed) { revert(0, 0) }
            }
            return _deployed;
        }

        revert("unlinked or missing artifact and no fallback");
    }

    function _deployedCodeMatches(
        address _addr,
        string memory _artifactPath
    )
        internal view
        returns (bool)
    {
        if (_addr == address(0)) {
            return false;
        }
        bytes memory onChain = _addr.code;
        bytes memory expected = vm.getDeployedCode(_artifactPath);
        return keccak256(onChain) == keccak256(expected);
    }

    function _findDeployedAddressFromFile(
        string memory path,
        string memory facetName
    )
        internal view
        returns (address)
    {
        string memory json = vm.readFile(path);
        for (uint256 i = 0; ; i++) {
            string memory idx = vm.toString(i);
            string memory namePath = string.concat("[", idx, "].name");
            bytes memory rawName = json.parseRaw(namePath);
            if (rawName.length == 0) {
                break;
            }
            string memory aName = abi.decode(rawName, (string));
            if (_stringEq(aName, facetName)) {
                string memory addrPath = string.concat("[", idx, "].address");
                bytes memory rawAddr = json.parseRaw(addrPath);
                if (rawAddr.length > 0) {
                    return abi.decode(rawAddr, (address));
                }
            }
        }
        return address(0);
    }

    function _actionName(
        IDiamondCut.FacetCutAction _action
    )
        internal pure
        returns (string memory)
    {
        if (_action == IDiamond.FacetCutAction.Add) {
            return "Add";
        } else if (_action == IDiamond.FacetCutAction.Replace) {
            return "Replace";
        } else if (_action == IDiamond.FacetCutAction.Remove) {
            return "Remove";
        }
        return "Unknown";
    }

    function _addrToString(
        address _a
    )
        internal pure
        returns (string memory)
    {
        return vm.toString(_a);
    }

    function _bytesToString(
        bytes memory _b
    )
        internal pure
        returns (string memory)
    {
        return vm.toString(_b);
    }

    function _stringEq(
        string memory _a,
        string memory _b
    )
        internal pure
        returns (bool)
    {
        return keccak256(bytes(_a)) == keccak256(bytes(_b));
    }

    function _toHex(bytes4 _selector) internal pure returns (string memory) {
        bytes memory b = abi.encodePacked(_selector);
        bytes memory hexChars = "0123456789abcdef";
        bytes memory str = new bytes(8);
        for (uint256 i = 0; i < 4; i++) {
            str[i * 2] = hexChars[uint8(b[i] >> 4)];
            str[i * 2 + 1] = hexChars[uint8(b[i] & 0x0f)];
        }
        return string(str);
    }

    function _toHexBytes(bytes memory _data) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory str = new bytes(_data.length * 2);
        for (uint256 i = 0; i < _data.length; i++) {
            str[i * 2] = hexChars[uint8(_data[i] >> 4)];
            str[i * 2 + 1] = hexChars[uint8(_data[i] & 0x0f)];
        }
        return string(str);
    }
}
