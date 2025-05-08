// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


/**
 * USDT Swapper contract is used to swap USDT.e for USDT0 at a 1:1 ratio.
 */
contract USDTSwapper {
    using SafeERC20 for IERC20Metadata;

    /// USDT.e token
    IERC20Metadata public immutable usdte;
    /// USDT0 token
    IERC20Metadata public immutable usdt0;

    /// Owner of the contract
    address public immutable owner;

    /// Paused state
    bool public paused;

    /// Event emitted when a swap occurs
    event Swapped(address indexed sender, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    /**
     * Constructor
     * @param _owner owner of the contract
     * @param _usdte address of the USDT.e token
     * @param _usdt0 address of the USDT0 token
     */
    constructor(address _owner, IERC20Metadata _usdte, IERC20Metadata _usdt0) {
        owner = _owner;
        usdte = _usdte;
        usdt0 = _usdt0;
    }

    /**
     * Swap USDT.e for USDT0 at a 1:1 ratio
     * @param _amount amount of USDT.e to swap for USDT0
     */
    function swap(uint256 _amount) external {
        require(!paused, "swapping is paused");
        usdte.safeTransferFrom(msg.sender, address(this), _amount);
        usdt0.safeTransfer(msg.sender, _amount);
        emit Swapped(msg.sender, _amount);
    }

    ////////////////////////// OWNER METHODS //////////////////////////

    /**
     * Pause swapping
     */
    function pause() external onlyOwner {
        paused = true;
    }

    /**
     * Unpause swapping
     */
    function unpause() external onlyOwner {
        paused = false;
    }

    /**
     * Deposit USDT0 into the contract
     */
    function depositUSDT0(uint256 _amount) external onlyOwner {
        usdt0.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
     * Withdraw USDT0 from the contract
     * @param _amount amount of USDT0 to withdraw
     */
    function withdrawUSDT0(uint256 _amount) external onlyOwner {
        usdt0.safeTransfer(msg.sender, _amount);
    }

    /**
     * Withdraw USDT.e from the contract
     * @param _amount amount of USDT.e to withdraw
     */
    function withdrawUSDTe(uint256 _amount) external onlyOwner {
        usdte.safeTransfer(msg.sender, _amount);
    }
}
