// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin-contracts/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {IMorpho, MarketParams, Id, Position, Market} from "./interfaces/IMorpho.sol";

/// @title MorphoEarn
/// @notice Earn-side wrapper around Morpho Blue. Users deposit the loan token
///         of a market and accrue interest paid by borrowers of that market.
///         No collateral / borrow operations.
///
///         To withdraw, the user must first authorize this contract on Morpho
///         via `morpho.setAuthorization(thisContract, true)` so the contract
///         can move their supply position.
contract MorphoEarn is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IMorpho public immutable morpho;

    event Deposited(address indexed user, Id indexed id, uint256 assets, uint256 shares);
    event Withdrawn(address indexed user, Id indexed id, uint256 assets, uint256 shares, address to);

    error ZeroAddress();
    error ZeroAmount();

    constructor(address _morpho) Ownable(msg.sender) {
        if (_morpho == address(0)) revert ZeroAddress();
        morpho = IMorpho(_morpho);
    }

    /// @notice Deposit `assets` of the market's loan token to start earning yield.
    function deposit(MarketParams calldata params, uint256 assets)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 assetsSupplied, uint256 sharesSupplied)
    {
        if (assets == 0) revert ZeroAmount();

        IERC20(params.loanToken).safeTransferFrom(msg.sender, address(this), assets);
        IERC20(params.loanToken).forceApprove(address(morpho), assets);

        (assetsSupplied, sharesSupplied) = morpho.supply(params, assets, 0, msg.sender, "");

        emit Deposited(msg.sender, _id(params), assetsSupplied, sharesSupplied);
    }

    /// @notice Withdraw a specific `assets` amount of loan token to `to`.
    ///         Caller must have authorized this contract on Morpho.
    function withdraw(MarketParams calldata params, uint256 assets, address to)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 assetsWithdrawn, uint256 sharesWithdrawn)
    {
        if (assets == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        (assetsWithdrawn, sharesWithdrawn) = morpho.withdraw(params, assets, 0, msg.sender, to);

        emit Withdrawn(msg.sender, _id(params), assetsWithdrawn, sharesWithdrawn, to);
    }

    /// @notice Withdraw the caller's entire position by burning all supply shares.
    ///         Avoids share-to-asset rounding reverts and claims accrued yield.
    function withdrawAll(MarketParams calldata params, address to)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 assetsWithdrawn, uint256 sharesWithdrawn)
    {
        if (to == address(0)) revert ZeroAddress();

        uint256 shares = morpho.position(_id(params), msg.sender).supplyShares;
        if (shares == 0) revert ZeroAmount();

        (assetsWithdrawn, sharesWithdrawn) = morpho.withdraw(params, 0, shares, msg.sender, to);

        emit Withdrawn(msg.sender, _id(params), assetsWithdrawn, sharesWithdrawn, to);
    }

    /// @notice View the caller's earn position: supply shares + estimated
    ///         underlying assets at current interest index.
    function getEarnPosition(MarketParams calldata params, address user)
        external
        view
        returns (uint256 supplyShares, uint256 estimatedAssets)
    {
        Id id = _id(params);
        Position memory p = morpho.position(id, user);
        Market memory m = morpho.market(id);

        supplyShares = p.supplyShares;
        if (m.totalSupplyShares == 0) {
            estimatedAssets = 0;
        } else {
            estimatedAssets = (supplyShares * uint256(m.totalSupplyAssets)) / uint256(m.totalSupplyShares);
        }
    }

    function marketId(MarketParams calldata params) external pure returns (Id) {
        return _id(params);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _id(MarketParams calldata params) internal pure returns (Id) {
        return Id.wrap(keccak256(abi.encode(params)));
    }
}
