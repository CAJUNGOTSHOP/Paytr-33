// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {Paytr} from "../src/Paytr.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Paytr_Helpers} from "../helpers/Helper_config.sol";

interface IComet {
    function supply(address asset, uint amount) external;
    function withdraw(address asset, uint amount) external;
    function baseToken() external view returns (address);
    function allow(address manager, bool isAllowed) external;
}

contract Paytr_Helpers is Test {
    using SafeERC20 for IERC20;
    
    Paytr Paytr_Test;

    //SEPOLIA USDC
    // IERC20 comet = IERC20(0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e);
    // address cometAddress = address(0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e);
    // IERC20 baseAsset = IERC20(IComet(0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e).baseToken());
    // address baseAssetAddress = IComet(0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e).baseToken();
    // IERC20 cometWrapper = IERC20(0xC3836072018B4D590488b851d574556f2EeB895a);
    // address cometWrapperAddress = address(0xC3836072018B4D590488b851d574556f2EeB895a);
    // IERC20 compToken = IERC20(0xA6c8D1c55951e8AC44a0EaA959Be5Fd21cc07531);

    // address alice = address(0x9);
    // address bob = address(0x2);
    // address charlie = address(0x3);
    // address dummyFeeAddress = address(0x4);
    // address owner = address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
    // address whale = address(0x75C0c372da875a4Fc78E8A37f58618a6D18904e8);

    //BASE SEPOLIA USDC
    IERC20 comet = IERC20(0x571621Ce60Cebb0c1D442B5afb38B1663C6Bf017);
    address cometAddress = address(0x571621Ce60Cebb0c1D442B5afb38B1663C6Bf017);
    IERC20 baseAsset = IERC20(IComet(0x571621Ce60Cebb0c1D442B5afb38B1663C6Bf017).baseToken());
    address baseAssetAddress = IComet(0x571621Ce60Cebb0c1D442B5afb38B1663C6Bf017).baseToken();
    IERC20 cometWrapper = IERC20(0x383eCD943E338357c0D81942933acA781C2E74cE);
    address cometWrapperAddress = address(0x383eCD943E338357c0D81942933acA781C2E74cE);
    IERC20 compToken = IERC20(0x2f535da74048c0874400f0371Fba20DF983A56e2);

    address alice = address(0x9);
    address bob = address(0x2);
    address charlie = address(0x3);
    address dummyFeeAddress = address(0x4);
    address owner = address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
    address whale = address(0xFaEc9cDC3Ef75713b48f46057B98BA04885e3391);

    bytes paymentReference1 = "0x494e56332d32343001";
    bytes paymentReference2 = "0x494e56332d32343002";
    bytes paymentReference3 = "0x494e56332d32343003";
    bytes paymentReference4 = "0x494e56332d32343004";
    bytes paymentReference5 = "0x494e56332d32343005";
    bytes paymentReference6 = "0x494e56332d32343006";
    bytes paymentReference7 = "0x494e56332d32343007";
    bytes paymentReference8 = "0x494e56332d32343008";
    bytes paymentReference9 = "0x494e56332d32343009";
    bytes paymentReference10 = "0x494e56332d32343010";
    bytes paymentReference11 = "0x494e56332d32343011";
    bytes paymentReference12 = "0x494e56332d32343012";
    bytes paymentReference13 = "0x494e56332d32343013";
    bytes paymentReference14 = "0x494e56332d32343014";
    bytes paymentReference15 = "0x494e56332d32343015";
    bytes paymentReference16 = "0x494e56332d32343016";

    bytes[] public payOutArray;

    event PaymentERC20Event(address tokenAddress, address payee, address feeAddress, uint256 amount, uint40 dueDate, uint256 feeAmount, bytes paymentReference);
    event PayOutERC20Event(address tokenAddress, address payee, address feeAddress, uint256 amount, bytes paymentReference, uint256 feeAmount);
    event InterestPayoutEvent(address tokenAddress, address payee, uint256 interestAmount, bytes paymentReference);
    event ContractParametersUpdatedEvent(uint16 feeModifier, uint256 minDueDateParameter, uint256 maxDueDateParameter, uint256 minAmount, uint8 maxPayoutArraySize);
    event SetERC20FeeProxyEvent(address ERC20FeeProxyAddress);
    
    //external contracts events:
    event TransferWithReferenceAndFee(address tokenAddress, address to, uint256 amount, bytes indexed paymentReference, uint256 feeAmount, address feeAddress);

    function getContractCometWrapperBalance() public view returns(uint256) {
        uint256 contractCometWrapperBalance = cometWrapper.balanceOf(address(Paytr_Test));
        return contractCometWrapperBalance;
    }

    function getContractBaseAssetBalance() public view returns(uint256) {
        uint256 contractBaseAssetBalance = baseAsset.balanceOf(address(Paytr_Test));
        return contractBaseAssetBalance;
    }

    function getAlicesBaseAssetBalance() public view returns(uint256) {
        uint256 alicesBaseAssetBalance = baseAsset.balanceOf(alice);
        return alicesBaseAssetBalance;
    }
    
    function getBobsBaseAssetBalance() public view returns(uint256) {
        uint256 bobsBaseAssetBalance = baseAsset.balanceOf(bob);
        return bobsBaseAssetBalance;
    }
    
    function getCharliesBaseAssetBalance() public view returns(uint256) {
        uint256 charliesBaseAssetBalance = baseAsset.balanceOf(charlie);
        return charliesBaseAssetBalance;
    }

    function getDummyFeeBaseAssetBalance() public view returns(uint256) {
        uint256 dummyFeesBaseAssetBalance = baseAsset.balanceOf(dummyFeeAddress);
        return dummyFeesBaseAssetBalance;
    }

    function transferBaseAsset() internal {
        //deal baseAsset
        //deal(address(baseAsset), alice, 10_000e6);
        vm.startPrank(whale);
        baseAsset.transfer(alice, 50_000_000e6);
        uint256 balanceAlice = baseAsset.balanceOf(alice);
        assertEq(balanceAlice, 50_000_000e6);
        //deal(address(baseAsset), bob, 10_000e6);
        baseAsset.transfer(bob, 50_000_000e6);
        uint256 balanceBob = baseAsset.balanceOf(bob);
        assertEq(balanceBob, 50_000_000e6);
        //deal(address(baseAsset), charlie, 10_000e6);
        baseAsset.transfer(charlie, 50_000_000e6);
        uint256 balanceCharlie = baseAsset.balanceOf(charlie);
        assertEq(balanceCharlie, 50_000_000e6);
        vm.stopPrank();
    }

    function approveBaseAsset() public {
        //approve baseAsset to contract
        vm.startPrank(alice);
        baseAsset.approve(address(Paytr_Test), 2**256 - 1);
        vm.stopPrank();
        vm.startPrank(bob);
        baseAsset.approve(address(Paytr_Test), 2**256 - 1);
        vm.stopPrank();
        vm.startPrank(charlie);
        baseAsset.approve(address(Paytr_Test), 2**256 - 1);
        vm.stopPrank();
    }

    function updateDueDate(bytes storage _paymentrefence) internal {
        vm.startPrank(alice);
        Paytr_Test.releaseEscrowPayment(_paymentrefence);
        vm.stopPrank();
    }

}