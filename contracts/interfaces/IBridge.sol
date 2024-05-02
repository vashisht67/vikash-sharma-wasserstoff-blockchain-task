// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBridge {
    event Deposit(
        address user,
        address sourceToken,
        address to,
        uint256 amount,
        uint256 id,
        uint128 depositTime,
        uint32 destinationChainType,
        bool isNativeCurrency
    );

    event Trigger(
        address token,
        address to,
        uint256 amount,
        uint256 id,
        uint32 sourcChainType,
        bool completed
    );

    function deposit(
        address _token,
        address _to,
        uint256 _amount,
        uint32 _destinationChainType
    ) external payable;

    function trigger(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _id,
        uint32 _sourceChainType,
        bool _isNativeCurrency,
        bytes memory _signature
    ) external;
}
