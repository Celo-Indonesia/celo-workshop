// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IToken} from "./interfaces/IToken.sol";
import {AccessControl} from "@openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin-contracts/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";

contract JointVentures is AccessControl, Pausable, ReentrancyGuard {
    
    bytes32 public constant FINANCE_ROLE = keccak256("FINANCE_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    IToken public tokenShares;
    IPriceFeed public priceFeed;
    
    address public finance;
    uint256 public target;
    mapping(address => uint256) public collected;
    uint256 public collectedUSD;
    bool public active;

    mapping(address => bool) public isTokenInWhitelist;

    string public nameMarket;
    address[] public registeredMembers;

    mapping(address => mapping(address => uint256)) public contributions;

    struct MemberData {
        string name;
        uint256 amount;
        bool isMember;
    }

    mapping(address => MemberData) public members;

    error OnlyFinance();
    error RegisteredMember();
    error NotActive();
    error NotRegisteredMember();
    error NotWhitelistedToken();

    event FinanceSet(address newFinance);
    event Activate(bool activate);
    event TargetSet(uint256 newTargetTotal);
    event Registered(address indexed member, string name);
    event Deposited(address indexed member, uint256 amount);

    constructor(
        address _tokenShares,
        address _priceFeed
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        tokenShares = IToken(_tokenShares);
        priceFeed = IPriceFeed(_priceFeed);
    }

    function setFinance(address _finance) external onlyRole(DEFAULT_ADMIN_ROLE) {
        finance = _finance;
        emit FinanceSet(_finance);
    }

    function activate(bool _activate) external onlyRole(OPERATOR_ROLE) {
        active = _activate;

        emit Activate(_activate);
    }

    function setTokenWhitelist(address _token) external onlyRole(FINANCE_ROLE) {
        isTokenInWhitelist[_token] = true;
    }

    function setTarget(uint256 _target) external onlyRole(FINANCE_ROLE) {
        target = _target;

        emit TargetSet(_target);
    }

    function register(string calldata _name) external nonReentrant whenNotPaused {
        if (members[msg.sender].isMember) revert RegisteredMember();

        members[msg.sender] = MemberData({name: _name, amount: 0, isMember: true});
        registeredMembers.push(msg.sender);

        emit Registered(msg.sender, _name);
    }

    function deposit(address _tokenIn, uint256 _amount) external nonReentrant whenNotPaused {
        require(active, NotActive());
        if (members[msg.sender].isMember == false) revert NotRegisteredMember();
        if (!isTokenInWhitelist[_tokenIn]) revert NotWhitelistedToken();
        
        _deposit(_tokenIn, _amount);

        emit Deposited(msg.sender, _amount);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _deposit(address _token, uint256 _amount) internal {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        contributions[msg.sender][_token] += _amount;
        collected[_token] += _amount;

        (uint256 price, uint256 decimals) = priceFeed.getChainlinkDataFeedLatestAnswer(_token);
        uint256 amountInUSD = (_amount * price) / (10 ** decimals);
        collectedUSD += amountInUSD;

        tokenShares.mintByContract(msg.sender, _amount);
    }
}
