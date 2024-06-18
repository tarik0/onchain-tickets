// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV3Factory.sol";
import "../../interfaces/IUniswapV3Pool.sol";
import "../../interfaces/ISwapRouter02.sol";


abstract contract Trade is
    Ownable,
    ReentrancyGuard
{
    ///
    /// Allows the contract to set the tax details
    /// - tax details include prize pool & referral tax
    /// - prize pool tax is set to 2.7% by default
    /// - referral tax is set to 0.3% by default
    ///

    struct Tax {
        uint256 Numerator;
        uint256 Denominator;
    }

    Tax private _prizePoolTax = Tax(270, 10_000);

    event PrizePoolTaxSet(Tax tax);
    error InvalidTaxValue();

    function setPrizePoolTax(Tax calldata tax) external onlyOwner {
        if (tax.Numerator > tax.Denominator) {
            revert InvalidTaxValue();
        }
        if ((100 * tax.Numerator / tax.Denominator) > 5) {
            revert InvalidTaxValue();
        }
        _prizePoolTax = tax;
        emit PrizePoolTaxSet(tax);
    }
    function _getPrizePoolTax() internal view returns (Tax memory) {
        return _prizePoolTax;
    }
    function prizePoolTax() external view returns (Tax memory) {
        return _getPrizePoolTax();
    }

    ///
    /// Allows the contract to exclude certain addresses from tax
    /// - owner & contract address are excluded by default
    ///
    /// isExcludedFromTax -> returns if an address is excluded from tax
    /// setExcludeTax -> allows owner to exclude an address from tax
    ///

    mapping(address => bool) private _excludedFromTax;

    event TaxExcludeChanged(address account, bool state);

    function _setExcludedFromTax(address account, bool state) internal {
        _excludedFromTax[account] = state;
    }
    function _getExcludedFromTax(address account) internal view returns (bool) {
        return _excludedFromTax[account] || account == owner() || account == address(this);
    }
    function isExcludedFromTax(address account) external view returns (bool) {
        return _getExcludedFromTax(account);
    }
    function setExcludeTax(address account, bool state) external onlyOwner {
        _setExcludedFromTax(account, state);
        emit TaxExcludeChanged(account, state);
    }

    ///
    /// Allows contract to set the max wallet holding amount
    /// - max wallet holding amount is the maximum amount of tokens a wallet can hold
    /// - tax excluded addresses & pair are not affected by the max wallet holding amount
    /// - max wallet holding amount can be minimum 25 tokens
    ///

    uint256 private _maxWallet = type(uint256).max;

    error InvalidMaxWallet();
    error MaxWalletExceeded();

    event MaxWalletChanged(uint256 amount);

    modifier checkMaxWallet(address to_, uint256 amount) {
        // skip if excluded from tax & pair
        if (_getExcludedFromTax(to_) || to_ == _pool()) {
            _;
            return;
        }

        // check if max wallet is exceeded
        uint256 balance = IERC20(address(this)).balanceOf(to_);
        if (balance + amount > _maxWallet) {
            revert MaxWalletExceeded();
        }
        _;
    }

    function _setMaxWallet(uint256 amount) internal {
        _validateMaxWallet(amount);
        _maxWallet = amount;
    }
    function _getMaxWallet() internal view returns (uint256) {
        return _maxWallet;
    }
    function _validateMaxWallet(uint256 amount) private pure {
        if (amount < 500 * 10**18) {  // 500 tokens
            revert InvalidMaxWallet();
        }
    }
    function setMaxWallet(uint256 amount) external onlyOwner {
        _setMaxWallet(amount);
        emit MaxWalletChanged(amount);
    }
    function maxWallet() external view returns (uint256) {
        return _getMaxWallet();
    }

    ///
    /// Allows the contract to set pool details
    /// - pool details include router, pool, WETH9 & fee
    ///

    struct PoolDetails {
        address payable Router;
        address Pool;
        address WETH9;
        uint24 Fee;
    }

    PoolDetails private _poolDetails;

    event PoolDetailsSet(PoolDetails details);

    function _initializePool(address payable router_, uint24 fee_) internal {
        // check if router is valid & fetch factory
        ISwapRouter02 swapRouter = ISwapRouter02(payable(router_));
        IUniswapV3Factory factory = IUniswapV3Factory(swapRouter.factory());

        // check if parity is valid
        address parity_ = swapRouter.WETH9();
        address pool_ = factory.getPool(parity_, address(this), fee_);
        if (pool_ == address(0)) {
            pool_ = factory.createPool(parity_, address(this), fee_);
        }

        // set pool details
        PoolDetails memory details = PoolDetails({
            Router: router_,
            Pool: pool_,
            WETH9: parity_,
            Fee: fee_
        });
        _poolDetails = details;
        emit PoolDetailsSet(details);
    }
    function _router() internal view returns (address payable) {
        return _poolDetails.Router;
    }
    function _pool() internal view returns (address) {
        return _poolDetails.Pool;
    }
    function _WETH9() internal view returns (address) {
        return _poolDetails.WETH9;
    }
    function pool() external view returns (PoolDetails memory) {
        return _poolDetails;
    }

    ///
    /// Allows contract to swap-back tokens to ether
    /// - swap-back tokens to ether is done via Uniswap V3
    /// - minimum amount of tokens to swap is 1 token
    ///

    event PrizePoolIncreased(uint256 amountOut);

    function _swapTokens() internal {
        // check amounts to swap
        uint256 tokenBalance = IERC20(address(this)).balanceOf(address(this));
        if (tokenBalance < 1e18) {  // 1 token min.
            return;
        }

        // swap token prize pool to ether
        PoolDetails memory details = _poolDetails;
        emit PrizePoolIncreased(ISwapRouter02(details.Router).exactInputSingle(
            IV3SwapRouter.ExactInputSingleParams({
                tokenIn: address(this),
                tokenOut: details.WETH9,
                fee: details.Fee,
                recipient: address(this),
                amountIn: tokenBalance,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        ));
    }

    ///
    /// Allows contract to calculate the ticket price via Uniswap V3
    ///
    /// ticketPrices -> returns the current & initial ticket price
    ///

    error InvalidPrice();

    uint256 private _initialPrice;

    function _fetchSqrtPrice() internal view returns (uint160) {
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(_pool()).slot0();
        return sqrtPriceX96;
    }
    function _getTicketPrice() internal view returns (uint256) {
        return _sqrtPriceToPrice(_fetchSqrtPrice());
    }
    function _getInitialPrice() internal view returns (uint256) {
        return _initialPrice;
    }
    function _resetInitialSqrtPrice() internal {
        _initialPrice = _sqrtPriceToPrice(_fetchSqrtPrice());
        if (_initialPrice == 0) {
            revert InvalidPrice();
        }
    }
    function _sqrtPriceToPrice(uint160 sqrtPriceX96_) private view returns (uint256) {
        if (sqrtPriceX96_ == 0) {
            return 0;
        }
        uint256 price = (uint256(sqrtPriceX96_) * uint256(sqrtPriceX96_) * 1e9) >> (96 * 2);
        price *= 1e9;
        return address(this) > _WETH9() ? 1e36 / price : price;
    }
    function ticketPrices() external view returns (uint256 current, uint256 initial) {
        return (_getTicketPrice(), _getInitialPrice());
    }
}