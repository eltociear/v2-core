pragma solidity >=0.8.19;

import "../../src/interfaces/external/IWETH9.sol";

contract MockWeth is IWETH9 {
    constructor(string memory name, string memory symbol)
        payable
    {
        // be default 18 decimals: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/abdb20a6bdb1700d58ea9e01b7471dafdef52a68/contracts/token/ERC20/ERC20.sol#L48
        //mint(msg.sender, 1e12);
    }

    function deposit() public payable override {
    }

    function withdraw(uint256 amount) public override {
    }

    function allowance(address owner, address spender) external view returns (uint256){
        return 0;
    }

    function approve(address spender, uint256 amount) external returns (bool){
        return false;
    }

    function balanceOf(address owner) external view returns (uint256){
        return 0;
    }

    function decimals() external view returns (uint8) {
        return 0;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool){
        return false;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool){
        return false;
    }

    function name() external view returns (string memory) {
        return "";
    }

    function symbol() external view returns (string memory) {
        return "";
    }

    function totalSupply() external view returns (uint256){
        return 0;
    }

    function transfer(address to, uint256 amount) external returns (bool){
        return false;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool){
        return false;
    }
}
