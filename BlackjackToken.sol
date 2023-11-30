pragma solidity ^0.5.0;

import "./ERC20.sol";

contract BlackjackToken {
    ERC20 erc20Contract;
    address owner;
    uint256 conversionRate;

    constructor() public {
        ERC20 e = new ERC20();
        erc20Contract = e;
        owner = msg.sender;
        // 1 ETH = 1000 BT
        conversionRate = 1000;
    }

    /**
    * @dev Function to give BT to the recipient for a given wei amount
    * @param recipient address of the recipient that wants to buy BT
    * @param weiAmt uint256 amount indicating the amount of wei that was passed
    * @return A uint256 representing the amount of BT bought by the msg.sender.
    */
    function getCredit(address recipient, uint256 weiAmt) public returns (uint256) {
        uint256 amt = weiAmt / (1E18/conversionRate); // Convert weiAmt to Dice Token
        erc20Contract.mint(recipient, amt);
        return amt; 
    }


    /**
    * @dev Function to check the amount of BT the msg.sender has
    * @param ad address of the recipient that wants to check their BT balance
    * @return A uint256 representing the amount of BT owned by the msg.sender
    */
    function checkCredit(address ad) public view returns (uint256) {
        uint256 credit = erc20Contract.balanceOf(ad);
        return credit;
    }


    /**
    * @dev Function to transfer the credit from the owner to the recipient
    * @param recipient address of the recipient that will gain in BT
    * @param amt uint256 amount of BT to transfer
    */
    function transferCredit(address recipient, uint256 amt) public {
        // Transfers from tx.origin to receipient
        erc20Contract.transfer(recipient, amt);
    }

    function getConversionRate() public view returns (uint256) {
        return conversionRate;
    }
}
