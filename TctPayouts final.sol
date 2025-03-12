// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

contract PayoutsTCT {
    address public owner = 0x494dB08F9c6b01CAed2B2e442d59BF509f50d4Bb;
    address private _pendingOwner;
    IERC20 public TCT;
    IERC20 public USDT;
    bool private _paused;
    bool private _locked;
    uint256 private constant MAX_BATCH_SIZE = 100;
    uint256 private constant DECIMALS = 18;
    uint256 private constant DECIMALS_MULTIPLIER = 10**DECIMALS;

    event TokensDistributed(address indexed token, address indexed recipient, uint256 amount);
    event Paused(address account);
    event Unpaused(address account);
    event OwnershipTransferStarted(address indexed currentOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EmergencyWithdrawal(address indexed token, uint256 amount);
    event SpenderApproved(address indexed token, address indexed spender, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "PayoutsTCT: No es el propietario");
        _;
    }

    modifier whenNotPaused() {
        require(!_paused, "PayoutsTCT: Contrato pausado");
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "PayoutsTCT: Llamada reentrante no permitida");
        _locked = true;
        _;
        _locked = false;
    }

    constructor(address usdtAddress, address tctAddress) {
        require(usdtAddress != address(0), "PayoutsTCT: Direccion USDT invalida");
        require(tctAddress != address(0), "PayoutsTCT: Direccion TCT invalida");
        
        USDT = IERC20(usdtAddress);
        TCT = IERC20(tctAddress);
        
        // Verificar que USDT tiene 18 decimales
        require(USDT.decimals() == 18, "PayoutsTCT: USDT debe tener 18 decimales");
    }

    function _convertToTokenDecimals(uint256 wholeNumber, uint256 decimal) internal pure returns (uint256) {
        // wholeNumber: parte entera (ej: 47 para 47.5)
        // decimal: parte decimal (ej: 5 para 47.5, 25 para 47.25, 125 para 47.125)
        require(decimal < 1000, "PayoutsTCT: Maximo 3 decimales permitidos");
        
        uint256 wholePart = wholeNumber * DECIMALS_MULTIPLIER;
        uint256 decimalPart = 0;
        
        if (decimal > 0) {
            // Multiplicamos por 10^15 para manejar hasta 3 decimales (ya que tenemos 18 decimales en total)
            decimalPart = decimal * (DECIMALS_MULTIPLIER / 1000);
        }
        
        return wholePart + decimalPart;
    }

    function distributeUSDT(
        address[] calldata recipients, 
        uint256[] calldata wholeNumbers,
        uint256[] calldata decimals
    ) 
        external 
        onlyOwner 
        whenNotPaused 
    {
        require(
            recipients.length == wholeNumbers.length && 
            wholeNumbers.length == decimals.length,
            "PayoutsTCT: Arrays de diferente longitud"
        );

        uint256[] memory adjustedAmounts = new uint256[](recipients.length);
        for(uint256 i = 0; i < recipients.length; i++) {
            adjustedAmounts[i] = _convertToTokenDecimals(wholeNumbers[i], decimals[i]);
        }
        _distributeTokens(USDT, recipients, adjustedAmounts);
    }

    function distributeTCT(address[] calldata recipients, uint256[] calldata amounts) 
        external 
        onlyOwner 
        whenNotPaused 
    {
        _distributeTokens(TCT, recipients, amounts);
    }

    function _distributeTokens(
        IERC20 token, 
        address[] calldata recipients, 
        uint256[] memory amounts
    ) 
        internal 
        nonReentrant 
    {
        require(recipients.length > 0, "PayoutsTCT: Array de destinatarios vacio");
        require(recipients.length == amounts.length, "PayoutsTCT: Arrays de diferente longitud");
        require(recipients.length <= MAX_BATCH_SIZE, "PayoutsTCT: Lote demasiado grande");

        uint256 totalAmount;
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "PayoutsTCT: Destinatario invalido");
            require(amounts[i] > 0, "PayoutsTCT: Cantidad debe ser mayor a cero");
            totalAmount += amounts[i];
        }
        
        require(token.balanceOf(address(this)) >= totalAmount, "PayoutsTCT: Saldo insuficiente");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(token.transfer(recipients[i], amounts[i]), "PayoutsTCT: Transferencia fallida");
            emit TokensDistributed(address(token), recipients[i], amounts[i]);
        }
    }

    function pause() external onlyOwner {
        require(!_paused, "PayoutsTCT: Ya esta pausado");
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        require(_paused, "PayoutsTCT: Ya esta activo");
        _paused = false;
        emit Unpaused(msg.sender);
    }

    function emergencyWithdraw(IERC20 token) external onlyOwner {
        require(_paused, "PayoutsTCT: Debe estar pausado para retiro de emergencia");
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "PayoutsTCT: Sin saldo para retirar");
        require(token.transfer(owner, balance), "PayoutsTCT: Retiro fallido");
        emit EmergencyWithdrawal(address(token), balance);
    }

    function recoverTokens(IERC20 token, uint256 amount) external onlyOwner {
        require(token != USDT && token != TCT, "PayoutsTCT: No se pueden recuperar tokens principales");
        require(amount > 0, "PayoutsTCT: Cantidad debe ser mayor a cero");
        require(token.balanceOf(address(this)) >= amount, "PayoutsTCT: Saldo insuficiente");
        require(token.transfer(owner, amount), "PayoutsTCT: Recuperacion fallida");
    }

    function approveSpender(
        IERC20 token, 
        address spender, 
        uint256 amount
    ) 
        external 
        onlyOwner 
    {
        require(spender != address(0), "PayoutsTCT: Spender invalido");
        require(token.approve(spender, amount), "PayoutsTCT: Aprobacion fallida");
        emit SpenderApproved(address(token), spender, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "PayoutsTCT: Propietario nuevo invalido");
        require(newOwner != owner, "PayoutsTCT: Nuevo propietario debe ser diferente");
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == _pendingOwner, "PayoutsTCT: No es el propietario pendiente");
        address oldOwner = owner;
        owner = _pendingOwner;
        _pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, owner);
    }

    function getPendingOwner() external view returns (address) {
        return _pendingOwner;
    }

    function isPaused() external view returns (bool) {
        return _paused;
    }
}