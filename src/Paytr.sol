```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IComet {
    function supply(address asset, uint amount) external;
    function withdraw(address asset, uint amount) external;
    function baseToken() external view returns (address);
    function allow(address manager, bool isAllowed) external;
}

interface IERC20FeeProxy {
    function transferFromWithReferenceAndFee(
        address _tokenAddress,
        address _to,
        uint256 _amount,
        bytes calldata _paymentReference,
        uint256 _feeAmount,
        address _feeAddress
    ) external;
}

interface IWrapper {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function claimTo(address to) external;
}

/// @title   Paytr
/// @notice  Paytr allows you to earn by paying early.

contract Paytr is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error InvalidTotalAmount();
    error PaymentReferenceInUse();
    error ZeroAmount();
    error ZeroPayeeAddress();
    error ZeroFeeAddress();
    error DueDateNotAllowed();
    error NoPrePayment();
    error InvalidArrayLength();
    error ReferenceNotDue();
    error InvalidContractFeeModifier();
    error InvalidMinDueDate();
    error InvalidMaxDueDate();
    error InvalidMinAmount();
    error InvalidMaxArraySize();
    error NotPayer();
    error ReferenceNotInEscrow();

    address immutable public baseAsset;
    address public ERC20FeeProxyAddress;
    address immutable public wrapperAddress;
    address immutable public cometAddress;
    uint8 public maxPayoutArraySize;
    uint16 public contractFeeModifier;
    uint256 public minDueDateParameter;
    uint256 public maxDueDateParameter;   
    uint256 public minTotalAmountParameter;

    struct PaymentERC20 {
        uint256 amount;
        uint256 feeAmount;
        uint256 wrapperSharesReceived;
        uint40 dueDate;
        address payer;
        address payee;
        address feeAddress;
        bool shouldPayoutViaRequestNetwork;
    }

    constructor(address _cometAddress, address _wrapperAddress, uint16 _contractFeeModifier, uint256 _minDueDateParameter, uint256 _maxDueDateParameter, uint256 _minTotalAmountParameter, uint8 _maxPayoutArraySize) payable {
       setContractParameters(_contractFeeModifier, _minDueDateParameter, _maxDueDateParameter, _minTotalAmountParameter, _maxPayoutArraySize);
       cometAddress = _cometAddress;
       baseAsset = IComet(cometAddress).baseToken();
       wrapperAddress = _wrapperAddress;
       IComet(cometAddress).allow(wrapperAddress, true);
       ERC20FeeProxyAddress = address(0);
    }

    event PaymentERC20Event(address tokenAddress, address payee, address feeAddress, uint256 amount, uint40 dueDate, uint256 feeAmount, bytes paymentReference);
    event PayOutERC20Event(address tokenAddress, address payee, address feeAddress, uint256 amount, bytes paymentReference, uint256 feeAmount);
    event InterestPayoutEvent(address tokenAddress, address payee, uint256 interestAmount, bytes paymentReference);
    event ContractParametersUpdatedEvent(uint16 contractFeeModifier, uint256 minDueDateParameter, uint256 maxDueDateParameter, uint256 minTotalAmount, uint8 maxPayoutArraySize);
    event SetERC20FeeProxyEvent(address ERC20FeeProxyAddress);

    /// @notice paymentMapping keeps track of all the payments.
    mapping(bytes => PaymentERC20) public paymentMapping;

    /// @notice Make a payment using the Comet's baseAsset.
    /// @notice This function can't be used while it's paused.
    /// @notice The sum of _amount and _feeAmount needs to be greater than the minTotalAmountParameter.
    /// @param _payee The receiver of the payment.
    /// @param _feeAddress When using an additional fee, this is the address that will receive the _feeAmount.
    /// @param _dueDate The due date of the paymentReference, or invoice, in epoch time.
    /// @param _amount The baseAsset amount in wei.
    /// @param _feeAmount The total baseAsset fee amount in wei.
    /// @param _paymentReference Reference of the related payment.
    /// @param _shouldPayoutViaRequestNetwork This number determines whether or not the payout of the payment reference should run through the Request Network ERC20FeeProxy contract,
    /// to make sure the Request Network protocol can detect this payment. Use 1 if you want to route the payout through Request Network or use 0 if you don't want this.
    /// @dev Uses modifiers nonReentrant and whenNotPaused.
    /// @dev The parameter _dueDate needs to be inserted in epoch time.
    /// @dev The sum of _amount and _feeAmount needs to be greater than the minTotalAmountParameter.
    /// @dev Make sure to add salt to and hash the _paymentReference to increase privacy and prevent double references.
    /// @dev The parameter _shouldPayoutViaRequestNetwork is a uint8. Use 1-255 if you need the payout to go through the Request Network contract, use 0 if you don't need this.

    function payInvoiceERC20(
        address _payee,
        address _feeAddress,
        uint40 _dueDate,
        uint256 _amount,
        uint256 _feeAmount,
        bytes calldata _paymentReference,
        bool _shouldPayoutViaRequestNetwork
        ) external nonReentrant whenNotPaused {

            PaymentERC20 storage paymentERC20 = paymentMapping[_paymentReference];
            uint256 totalAmount = _amount + _feeAmount;

            if(_amount == 0) revert ZeroAmount();
            if(_payee == address(0)) revert ZeroPayeeAddress();
            if(_feeAddress == address(0)) revert ZeroFeeAddress();
            if(paymentERC20.amount != 0) revert PaymentReferenceInUse();
            if(totalAmount < minTotalAmountParameter) revert InvalidTotalAmount();
            if(_dueDate < uint40(block.timestamp + minDueDateParameter) || _dueDate > uint40(block.timestamp + maxDueDateParameter)) revert DueDateNotAllowed();

            IERC20(baseAsset).safeTransferFrom(msg.sender, address(this), totalAmount);
            
            uint256 cUsdcbalanceBeforeSupply = getContractCometBalance();
            IERC20(baseAsset).forceApprove(cometAddress, totalAmount);
            IComet(cometAddress).supply(baseAsset, totalAmount);
            uint256 cUsdcbalanceAfterSupply = getContractCometBalance();
            uint256 cUsdcAmountToWrap = cUsdcbalanceAfterSupply - cUsdcbalanceBeforeSupply;         

            uint256 wrappedShares = IWrapper(wrapperAddress).deposit(cUsdcAmountToWrap, address(this));

            paymentMapping[_paymentReference] = PaymentERC20({
                amount: _amount,
                feeAmount: _feeAmount,
                wrapperSharesReceived: wrappedShares,
                dueDate: _dueDate,
                payer: msg.sender,
                payee: _payee,
                feeAddress: _feeAddress,
                shouldPayoutViaRequestNetwork: _shouldPayoutViaRequestNetwork
        });  

        emit PaymentERC20Event(baseAsset, _payee, _feeAddress, _amount, _dueDate, _feeAmount, _paymentReference);         
    }

    /// @notice this function doesn't require a due date as parameter. It should be used for escrow payments where the release will be triggered manually.
    /// @notice This function can't be used while it's paused.
    /// @notice The sum of _amount and _feeAmount needs to be greater than the minTotalAmountParameter.
    /// @param _payee The receiver of the payment.
    /// @param _feeAddress When using an additional fee, this is the address that will receive the _feeAmount.
    /// @param _amount The baseAsset amount in wei.
    /// @param _feeAmount The total baseAsset fee amount in wei.
    /// @param _paymentReference Reference of the related payment.
    /// @param _shouldPayoutViaRequestNetwork This number determines whether or not the payout of the payment reference should run through the Request Network ERC20FeeProxy contract,
    /// to make sure the Request Network protocol can detect this payment. Use 1 if you want to route the payout through Request Network or use 0 if you don't want this.
    /// @dev Uses modifiers nonReentrant and whenNotPaused.
    /// @dev The sum of _amount and _feeAmount needs to be greater than the minTotalAmountParameter.
    /// @dev Make sure to add salt to and hash the _paymentReference to increase privacy and prevent double references.
    /// @dev The parameter _shouldPayoutViaRequestNetwork is a uint8. Use 1-255 if you need the payout to go through the Request Network contract, use 0 if you don't need this.
    function payInvoiceERC20Escrow(
        address _payee,
        address _feeAddress,
        uint256 _amount,
        uint256 _feeAmount,
        bytes calldata _paymentReference,
        bool _shouldPayoutViaRequestNetwork
        ) external nonReentrant whenNotPaused {

            PaymentERC20 storage paymentERC20 = paymentMapping[_paymentReference];
            uint256 totalAmount = _amount + _feeAmount;

            if(_amount == 0) revert ZeroAmount();
            if(_payee == address(0)) revert ZeroPayeeAddress();
            if(_feeAddress == address(0)) revert ZeroFeeAddress();
            if(paymentERC20.amount != 0) revert PaymentReferenceInUse();
            if(totalAmount < minTotalAmountParameter) revert InvalidTotalAmount();

            IERC20(baseAsset).safeTransferFrom(msg.sender, address(this), totalAmount);
            
            uint256 cUsdcbalanceBeforeSupply = getContractCometBalance();
            IERC20(baseAsset).forceApprove(cometAddress, totalAmount);
            IComet(cometAddress).supply(baseAsset, totalAmount);
            uint256 cUsdcbalanceAfterSupply = getContractCometBalance();
            uint256 cUsdcAmountToWrap = cUsdcbalanceAfterSupply - cUsdcbalanceBeforeSupply;         

            uint256 wrappedShares = IWrapper(wrapperAddress).deposit(cUsdcAmountToWrap, address(this));

            paymentMapping[_paymentReference] = PaymentERC20({
                amount: _amount,
                feeAmount: _feeAmount,
                wrapperSharesReceived: wrappedShares,
                dueDate: 0,
                payer: msg.sender,
                payee: _payee,
                feeAddress: _feeAddress,
                shouldPayoutViaRequestNetwork: _shouldPayoutViaRequestNetwork
            });

        emit PaymentERC20Event(baseAsset, _payee, _feeAddress, _amount, 0, _feeAmount, _paymentReference);         
    }

    /// @notice this function updates the due date of a payment and should be used when releasing escrow payments.
    /// @notice the original payment needs to have a due date of '0'.
    /// @notice only the payer of the _paymentReference can call this function.
    /// @notice the payout is not triggered by using this function. The payment reference is now marked to be due by updating the due date to the current block.timestamp + 770 minutes
    /// @notice 770 minutes (0.5 days) are added to prevent paying and immediately releasing a payment, which would cause useless gas usage for the payout.
    /// The _paymentReference will now be included in the next (automated) payout run, or can be triggered manually if needed
    /// @param _paymentReference Reference of the related payment
    function releaseEscrowPayment(bytes memory _paymentReference) external {
        PaymentERC20 storage paymentERC20 = paymentMapping[_paymentReference];
        
        if(msg.sender != paymentERC20.payer) revert NotPayer();
        if(paymentERC20.dueDate != 0) revert ReferenceNotInEscrow();
        if(paymentERC20.amount == 0) revert NoPrePayment();

        paymentERC20.dueDate = uint40(block.timestamp + 770 minutes);
    }
                                                                                
    /// @notice Allows the contract to pay payee (principal amount), payer (interest amount) and fee receiver (fee amount).
    /// This function cannot be paused.
    /// @param payoutReferencesArray Insert the bytes array of references that need to be paid out. Only due payment references can be used.
    /// @dev Uses modifier nonReentrant.
    function payOutERC20Invoice(bytes[] calldata payoutReferencesArray) external nonReentrant {

        uint256 payoutReferencesArrayLength = payoutReferencesArray.length;

        if(payoutReferencesArrayLength == 0 || payoutReferencesArrayLength > maxPayoutArraySize) revert InvalidArrayLength();
        
        for (uint256 i; i < payoutReferencesArrayLength; i++) {
            PaymentERC20 storage paymentERC20 = paymentMapping[payoutReferencesArray[i]];
            if(paymentERC20.amount == 0) revert NoPrePayment();
            if(paymentERC20.dueDate > block.timestamp || paymentERC20.dueDate == 0 ) revert ReferenceNotDue();
            bool RNPayment = paymentERC20.shouldPayoutViaRequestNetwork;

            address _payee = paymentERC20.payee;
            address _payer = paymentERC20.payer;
            address _feeAddress = paymentERC20.feeAddress;
            uint256 _amount = paymentERC20.amount;
            uint256 _feeAmount = paymentERC20.feeAmount;
            uint256 _wrapperSharesToRedeem = paymentERC20.wrapperSharesReceived;
            
            delete paymentMapping[payoutReferencesArray[i]];

            //redeem Wrapper shares and receive v3 cTokens
            IWrapper(wrapperAddress).redeem(_wrapperSharesToRedeem, address(this), address(this));

            uint256 baseAssetBalanceBeforeCometWithdraw = IERC20(baseAsset).balanceOf(address(this));

            //redeem all available v3 cTokens from Compound for baseAsset tokens
            uint256 cTokensToRedeem = IERC20(cometAddress).balanceOf(address(this));
            IComet(cometAddress).withdraw(baseAsset, cTokensToRedeem);

            //get new USDC balance
            uint256 baseAssetBalanceAfterCometWithdraw = IERC20(baseAsset).balanceOf(address(this));

            uint256 _totalInterestGathered = baseAssetBalanceAfterCometWithdraw - baseAssetBalanceBeforeCometWithdraw - _amount - _feeAmount;
            uint256 _interestAmount = _totalInterestGathered * contractFeeModifier / 10000;

            if(RNPayment == true) {
                IERC20FeeProxy(ERC20FeeProxyAddress).transferFromWithReferenceAndFee(
                    baseAsset,
                    _payee,
                    _amount,
                    payoutReferencesArray[i],
                    _feeAmount,
                    _feeAddress
                );                

            } else {
                
                IERC20(baseAsset).safeTransfer(_payee, _amount);
                if(_feeAmount != 0) {
                    IERC20(baseAsset).safeTransfer(_feeAddress, _feeAmount);
                }
                
            }

            IERC20(baseAsset).safeTransfer(_payer, _interestAmount);          

            emit PayOutERC20Event(baseAsset, _payee, _feeAddress, _amount, payoutReferencesArray[i], _feeAmount);
            emit InterestPayoutEvent(baseAsset, _payer, _interestAmount, payoutReferencesArray[i]);
        }

    }

    function getContractCometBalance() internal view returns(uint256) {
        uint256 contractCometBalance = IERC20(cometAddress).balanceOf(address(this));
        return contractCometBalance;
    }
    
    function claimCompRewards() external onlyOwner {
        IWrapper(wrapperAddress).claimTo(owner());
    }

    function claimBaseAssetBalance() external onlyOwner {
        IERC20(baseAsset).safeTransfer(owner(), IERC20(baseAsset).balanceOf(address(this)));
    }

    function setContractParameters(uint16 _contractFeeModifier, uint256 _minDueDateParameter, uint256 _maxDueDateParameter, uint256 _minTotalAmountParameter, uint8 _maxPayoutArraySize) public onlyOwner {
        if(_contractFeeModifier < 5000 || _contractFeeModifier > 10000 ) revert InvalidContractFeeModifier();
        if(_minDueDateParameter < 2 days) revert InvalidMinDueDate();
        if(_maxDueDateParameter > 365 days) revert InvalidMaxDueDate();
        if(_minTotalAmountParameter < 1) revert InvalidMinAmount();
        if(_maxPayoutArraySize == 0) revert InvalidMaxArraySize();
        contractFeeModifier = _contractFeeModifier;
        minDueDateParameter = _minDueDateParameter;
        maxDueDateParameter = _maxDueDateParameter;
        minTotalAmountParameter = _minTotalAmountParameter;
        maxPayoutArraySize = _maxPayoutArraySize;

        emit ContractParametersUpdatedEvent(_contractFeeModifier, _minDueDateParameter, _maxDueDateParameter, _minTotalAmountParameter, _maxPayoutArraySize);
    }

    function setERC20FeeProxy(address _ERC20FeeProxyAddress) external onlyOwner {
        ERC20FeeProxyAddress = _ERC20FeeProxyAddress;
        IERC20(baseAsset).forceApprove(ERC20FeeProxyAddress, type(uint256).max);

        emit SetERC20FeeProxyEvent(_ERC20FeeProxyAddress);
    }

    function getERC20FeeProxy() external view returns (address) {
        return ERC20FeeProxyAddress;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getMapping(bytes memory _paymentReference) external view returns(PaymentERC20 memory) {
        return paymentMapping[_paymentReference];
    }

}
```
