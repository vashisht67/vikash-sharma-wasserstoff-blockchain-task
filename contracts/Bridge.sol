// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBridge.sol";
import "./UtilityHelper.sol";

/**
 * @title Bridge Contract
 * @notice This contract allows users to lock a token on one chain and unlock an equivalent token on another chain through the bridge.
 */
contract Bridge is Ownable, ReentrancyGuard, IBridge {
    using SafeERC20 for IERC20;
    uint32 public currentChainType;
    uint256 public uniqueID;

    mapping(uint32 => mapping(uint256 => bool)) public txnId; // update mapping user deposit token or trigger

    /**
     * @notice Initializes the contract with initial values.
     * @param _currentChainType The current chain type.
     */
    constructor(
        uint32 _currentChainType,
        address _initialOwner
    ) Ownable(_initialOwner) {
        currentChainType = _currentChainType;
    }

    receive() external payable {
    }

    /***************************DEPOSIT FUNCTION************************** */

    /**
     * @notice Deposits a token to the contract and emits a bridge event.
     * @param _token The address of the token to deposit.
     * @param _to The address on the other chain to receive the equivalent token.
     * @param _amount The amount of the token to deposit.
     * @param _destinationChainType The type of chain.
     */
    function deposit(
        address _token,
        address _to,
        uint256 _amount,
        uint32 _destinationChainType
    ) external payable override nonReentrant {
        IERC20 token = IERC20(_token);
        bool isNativeCurrency;
        if (msg.value > 0) {
            isNativeCurrency = true;
            _amount = msg.value;
            (bool success, ) = address(this).call{value: _amount}("");
            require(
                success,
                "unable to send value or recipient may have reverted"
            );
        } else {
            //balance check
            require(
                token.balanceOf(msg.sender) >= _amount,
                "User doesn't have enough balance"
            );

            // Allowance Check
            require(
                token.allowance(msg.sender, address(this)) >= _amount,
                "Allowance provided is low"
            );
            token.safeTransferFrom(_msgSender(), address(this), _amount);
        }
        uniqueID++;
        txnId[currentChainType][uniqueID] = true;
        emit Deposit(
            msg.sender,
            _token,
            _to,
            _amount,
            uniqueID,
            uint128(block.timestamp),
            _destinationChainType,
            isNativeCurrency
        );
    }

    /*************************TRIGGER FUNCTION OR CLAIM FUNCTION*************************************/

    /***
     * @dev Triggers the bridging of a token on the other chain
     * @param _token The address of the token being bridged
     * @param _to The address receiving the bridged token
     * @param _amount The amount of the bridged token being transferred
     * @param _sourceChainType The type of chain (0 for Ethereum, 1 for BSC)
     * @return token The address of the wrapped token on the other chain
     */
    function trigger(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _id,
        uint32 _sourceChainType, // deposit chain type
        bool _isNativeCurrency,
        bytes memory _signature
    ) external nonReentrant onlyOwner {
        IERC20 token = IERC20(_token);
        require(!txnId[_sourceChainType][_id], "Transaction already exists");

        bytes32 message = UtilityHelper.prefixed(
            keccak256(
                abi.encodePacked(_token, _to, _sourceChainType, _amount, _id)
            )
        );

        require(
            UtilityHelper.recoverSigner(message, _signature) == owner(),
            "INVALID SIGNER !"
        );

        if (_isNativeCurrency) {
            (bool success, ) = payable(msg.sender).call{value: _amount}("");
            require(
                success,
                "unable to send value or recipient may have reverted"
            );
        } else {
            //balance check
            require(
                token.balanceOf(address(this)) >= _amount,
                "User doesn't have enough balance"
            );
            token.safeTransferFrom(_msgSender(), address(this), _amount);
        }

        txnId[_sourceChainType][_id] = true;

        emit Trigger(_token, _to, _amount, _id, _sourceChainType, true);
    }
}
