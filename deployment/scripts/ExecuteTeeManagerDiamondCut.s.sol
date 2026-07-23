// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IDiamond} from "../../contracts/diamond/interfaces/IDiamond.sol";
import {IDiamondCut} from "../../contracts/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../contracts/diamond/interfaces/IDiamondLoupe.sol";

// solhint-disable no-console
contract ExecuteTeeManagerDiamondCut is Script {
    using stdJson for string;

    struct DeployedContract {
        address addr;
        string contractName;
        string name;
    }

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

        address initAddr = _resolveInitContract(
            json, deployedContractsFile, facetNames, facetAddrs
        );
        vm.stopBroadcast();

        _writeDeploymentOutput(
            diamond,
            facetAddrs,
            facetNames,
            initAddr,
            execute,
            configFilePath
        );
    }

    function _resolveInitContract(
        string memory _json,
        string memory _deployedContractsFile,
        string[] memory _facetNames,
        address[] memory _facetAddrs
    )
        internal
        returns (address)
    {
        bytes memory rawInit = _json.parseRaw(".init");
        if (rawInit.length == 0) {
            return address(0);
        }
        bytes memory rawInitName = _json.parseRaw(".init.contract");
        require(rawInitName.length > 0, "init.contract is required if init object exists");
        string memory initName = abi.decode(rawInitName, (string));
        require(bytes(initName).length > 0, "init.contract cannot be empty");
        for (uint256 i = 0; i < _facetNames.length; i++) {
            if (_stringEq(_facetNames[i], initName)) {
                return _facetAddrs[i];
            }
        }
        // not found in facets — try reuse from deploys if code matches; else deploy
        address candidate = _findDeployedAddressFromFile(
            _deployedContractsFile, initName
        );
        string memory artifactPath = string.concat(
            "artifacts-forge/", initName, ".sol/", initName, ".json"
        );
        if (_deployedCodeMatches(candidate, artifactPath)) {
            return candidate;
        }
        address deployed = _deployFacet(initName);
        _updateAddressInFile(_deployedContractsFile, initName, deployed);
        return deployed;
    }

    function _writeDeploymentOutput(
        address _diamond,
        address[] memory _facetAddrs,
        string[] memory _facetNames,
        address _initAddress,
        bool _execute,
        string memory _configPath
    )
        internal
    {
        // Create output directory if it doesn't exist. Use vm.createDir instead of `mkdir -p` via
        // ffi so it works on every OS (forge's ffi can't spawn a POSIX `mkdir` on Windows).
        vm.createDir(string.concat("deployment/output-internal/", network), true);

        bytes memory out = _buildCutData(
            _diamond, _facetAddrs, _facetNames, _initAddress, _configPath
        );

        _executeOrLog(_diamond, out, _execute);
    }

    function _buildCutData(
        address _diamond,
        address[] memory _facetAddrs,
        string[] memory _facetNames,
        address _initAddress,
        string memory _configPath
    )
        internal
        returns (bytes memory)
    {
        // 1. read facets from diamond loupe
        IDiamondLoupe.Facet[] memory loupeFacets = IDiamondLoupe(_diamond).facets();
        // 2. write minimal text inputs for TS script
        string memory facetsPath = string.concat(
            "deployment/output-internal/", network, "/facets-", configFileName, ".txt"
        );
        string memory loupePath = string.concat(
            "deployment/output-internal/", network, "/loupe-", configFileName, ".txt"
        );
        _writeFacetsFile(facetsPath, _facetAddrs, _facetNames);
        _writeLoupeFile(loupePath, loupeFacets);
        // 3. call TS script via tsx which outputs ABI-encoded bytes
        bool hasInitAddr = _initAddress != address(0);
        uint256 len =
            4 /*node --import tsx script*/ +
            2 /*diamond*/ +
            2 /*facets-file*/ +
            2 /*loupe-file*/ +
            2 /*config*/ +
            (hasInitAddr ? 2 : 0);
        string[] memory cmd = new string[](len);
        uint256 k = 0;
        // Spawn `node --import tsx <script>` rather than `npx tsx <script>`: forge's ffi launches a
        // real executable and cannot run the `npx`/.cmd shim on Windows. Requires tsx as a devDependency.
        cmd[k++] = "node"; cmd[k++] = "--import"; cmd[k++] = "tsx";
        cmd[k++] = "deployment/utils/build-cut.ts";
        cmd[k++] = "--diamond"; cmd[k++] = _addrToString(_diamond);
        cmd[k++] = "--facets-file"; cmd[k++] = facetsPath;
        cmd[k++] = "--loupe-file"; cmd[k++] = loupePath;
        if (hasInitAddr) {
            cmd[k++] = "--init-address"; cmd[k++] = _addrToString(_initAddress);
        }
        cmd[k++] = "--config"; cmd[k++] = _configPath;
        return vm.ffi(cmd);
    }

    function _executeOrLog(
        address _diamond,
        bytes memory _out,
        bool _execute
    )
        internal
    {
        (
            IDiamond.FacetCut[] memory cuts,
            address initAddr,
            bytes memory initData
        ) = abi.decode(_out, (IDiamond.FacetCut[], address, bytes));

        _logCutData(_diamond, cuts, initAddr, initData);

        if (_execute) {
            vm.startBroadcast();
            IDiamondCut(_diamond).diamondCut(cuts, initAddr, initData);
            vm.stopBroadcast();
        } else {
            _writeOutputFiles(_out);
        }
    }

    function _writeOutputFiles(
        bytes memory _out
    )
        internal
    {
        string memory encodedPath = string.concat(
            "deployment/output-internal/", network, "/",
            "diamond-cut-encoded-", configFileName, ".bin"
        );
        vm.writeFileBinary(encodedPath, _out);
        string memory outputPath = string.concat(
            "deployment/output-internal/", network, "/",
            "decoded-", configFileName, ".json"
        );
        string[] memory prettyCmd = new string[](8);
        prettyCmd[0] = "node";
        prettyCmd[1] = "--import";
        prettyCmd[2] = "tsx";
        prettyCmd[3] = "deployment/utils/format-cut.ts";
        prettyCmd[4] = "--encoded-path";
        prettyCmd[5] = encodedPath;
        prettyCmd[6] = "--output-path";
        prettyCmd[7] = outputPath;
        vm.ffi(prettyCmd);
        string memory prettyJson = vm.readFile(outputPath);
        console2.log("---- Diamond cut not executed. Data for manual execution: ----");
        console2.log("decoded tuples (JSON):");
        console2.log(prettyJson);
        console2.log("---------------------------------------");
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
        // In a dry run (forge script without --broadcast) any facet deployed above is a *simulated*
        // CREATE address that never lands on-chain, so it must not overwrite the deploys registry.
        // Only persist addresses when actually broadcasting.
        if (vm.isContext(VmSafe.ForgeContext.ScriptDryRun)) {
            return;
        }
        string[] memory cmd = new string[](7);
        cmd[0] = "node";
        cmd[1] = "--import";
        cmd[2] = "tsx";
        cmd[3] = "deployment/utils/update-facet-address.ts";
        cmd[4] = _contractsFilePath;
        cmd[5] = _facetName;
        cmd[6] = _addrToString(_facetAddress);
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

    function _logCutData(
        address _diamond,
        IDiamond.FacetCut[] memory _cuts,
        address _initAddr,
        bytes memory _initData
    )
        internal view
    {
        console2.log("---- DIAMOND CUT DATA: ----");
        console2.log("diamond address:", _diamond);
        console2.log("number of cuts:", _cuts.length);
        for (uint256 i = 0; i < _cuts.length; i++) {
            console2.log(string(abi.encodePacked("cuts[", vm.toString(i), "]:")));
            console2.log("  facetAddress:", _cuts[i].facetAddress);
            console2.log("  action:", _actionName(_cuts[i].action));
            console2.log("  functionSelectors:");
            for (uint256 j = 0; j < _cuts[i].functionSelectors.length; j++) {
                console2.log(string(
                    abi.encodePacked(
                        "    [", vm.toString(j), "]: 0x", _toHex(_cuts[i].functionSelectors[j])
                    )
                ));
            }
        }
        console2.log("init data:");
        console2.log("  init address:", _initAddr);
        console2.log(string(abi.encodePacked("  init calldata: 0x", _toHexBytes(_initData))));
        bytes memory callData = abi.encodeWithSelector(
            IDiamondCut.diamondCut.selector, _cuts, _initAddr, _initData
        );
        console2.log(string(abi.encodePacked("diamondCut calldata: 0x", _toHexBytes(callData))));
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
        string memory _path,
        string memory _facetName
    )
        internal view
        returns (address)
    {
        string memory json = vm.readFile(_path);
        DeployedContract[] memory contracts =
            abi.decode(vm.parseJson(json), (DeployedContract[]));
        bytes32 nameHash = keccak256(bytes(_facetName));
        for (uint256 i = 0; i < contracts.length; i++) {
            if (keccak256(bytes(contracts[i].name)) == nameHash) {
                return contracts[i].addr;
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

    function _toHex(
        bytes4 _selector
    )
        internal pure
        returns (string memory)
    {
        bytes memory b = abi.encodePacked(_selector);
        bytes memory hexChars = "0123456789abcdef";
        bytes memory str = new bytes(8);
        for (uint256 i = 0; i < 4; i++) {
            str[i * 2] = hexChars[uint8(b[i] >> 4)];
            str[i * 2 + 1] = hexChars[uint8(b[i] & 0x0f)];
        }
        return string(str);
    }

    function _toHexBytes(
        bytes memory _data
    )
        internal pure
        returns (string memory)
    {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory str = new bytes(_data.length * 2);
        for (uint256 i = 0; i < _data.length; i++) {
            str[i * 2] = hexChars[uint8(_data[i] >> 4)];
            str[i * 2 + 1] = hexChars[uint8(_data[i] & 0x0f)];
        }
        return string(str);
    }
}
