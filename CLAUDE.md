# Coding Conventions

## Solidity Function Definition Formatting

All Solidity contracts and interfaces (excluding tests) must follow these formatting rules.

### Parameters
- If there are input parameters, each must be on its own line
- Closing `)` on its own line at function indent level (4 spaces)
- All input and output parameters must start with `_` (except in `try/catch` blocks)

### Visibility and Modifiers
- Visibility (`external`, `external view`, `public`, `public view`, `internal`, `internal view`, `private`, `private view`) on its own line (8 spaces indent)
- Keywords like `virtual`, `override`, `payable` stay on the visibility line (e.g., `public payable virtual override`)
- Custom modifiers (e.g., `onlyGovernance`, `onlyOwner(...)`) each on their own line after visibility (8 spaces indent)

### Returns
- `returns` keyword must have a space before `(`: `returns (` not `returns(`
- Single return parameter: stays on one line with `returns`
- Multiple return parameters: each on its own line (12 spaces indent), closing `)` on its own line (8 spaces indent)

### Braces
- For contracts (not interfaces), opening `{` on its own line at function indent level (4 spaces)
- For interfaces, functions end with `;`

### No-parameter Functions
- Same rules apply: visibility on new line, returns split to new lines when multiple

### Example (contract, with params and multiple returns)
```solidity
    function getTeeGovernance(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (
            address[] memory _signers,
            uint64 _signersThreshold
        )
    {
        // ...
    }
```

### Example (contract, with modifiers)
```solidity
    function upgradeToAndCall(
        address _newImplementation,
        bytes memory _data
    )
        public payable virtual override
        onlyGovernance
    {
        super.upgradeToAndCall(_newImplementation, _data);
    }
```

### Example (interface, single return)
```solidity
    function getOpType()
        external view
        returns (bytes32);
```

### Example (no params, multiple returns)
```solidity
    function getCosigners()
        external view
        returns (
            address[] memory _cosigners,
            uint64 _cosignersThreshold
        );
```

## Naming Conventions

- Internal methods (unless in libraries) and private methods must start with `_`
- All input and output parameters must start with `_` (except in `try/catch` blocks)
- Public/external methods and non-parameter variables should not start with `_`
