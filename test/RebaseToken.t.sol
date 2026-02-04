// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    uint256 public constant SEND_VALUE = 1e18;

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        payable(address(vault)).call{value: 1e8}("");
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool sucess,) = payable(address(vault)).call{value: rewardAmount}("");
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user1);
        vm.deal(user1, amount);
        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user1);
        console.log("RebaseToken balance after deposit:", startBalance);
        assertEq(startBalance, amount);

        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user1);
        assertGt(middleBalance, startBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user1);
        assertGt(endBalance, middleBalance);
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user1);
        vm.deal(user1, amount);
        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user1);
        console.log("RebaseToken balance after deposit:", startBalance);
        assertEq(startBalance, amount);

        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user1), 0);
        uint256 endEthBalance = user1.balance;
        console.log("ETH balance after redeeming immediately:", endEthBalance);
        assertEq(endEthBalance, amount);
        vm.stopPrank();
    }

    function testRedeeemAfterTimePassed(uint256 depositAmount, uint256 timePassed) public {
        timePassed = bound(timePassed, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);

        vm.deal(user1, depositAmount);
        vm.prank(user1);
        vault.deposit{value: depositAmount}();

        vm.warp(block.timestamp + timePassed);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user1);

        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - depositAmount);
        vm.prank(user1);
        vault.redeem(type(uint256).max);

        uint256 ethBalanceBefore = user1.balance;
        assertEq(ethBalanceBefore, balanceAfterSomeTime);
        assertGt(ethBalanceBefore, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e3, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e3);

        vm.deal(user1, amount);
        vm.prank(user1);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 user1BalanceBefore = rebaseToken.balanceOf(user1);
        uint256 user2BalanceBefore = rebaseToken.balanceOf(user2);

        assertEq(user1BalanceBefore, amount);
        assertEq(user2BalanceBefore, 0);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        vm.prank(user1);
        rebaseToken.transfer(user2, amountToSend);

        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user1);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, user1BalanceBefore - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        assertEq(rebaseToken.getUserInterestRate(user1), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }

    function testCannotSetInterestRateIfNotOwner(uint256 newInterestRate) public {
        newInterestRate = bound(newInterestRate, 0, type(uint96).max);

        vm.prank(user1);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotMintAndBrun() public {
        vm.prank(user1);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mint(user1, 100);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burn(user1, 100);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user1);
        vm.deal(user1, amount);
        vault.deposit{value: amount}();
        uint256 principalBalance = rebaseToken.principalBalanceOf(user1);
        assertEq(principalBalance, amount);
        vm.warp(block.timestamp + 1 hours);
        principalBalance = rebaseToken.principalBalanceOf(user1);
        assertEq(principalBalance, amount);
        vm.stopPrank();
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max);

        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }
}
