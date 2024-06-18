// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITickets404 {
    error AlreadyInitialized();
    error ApprovalCallerNotOwnerNorApproved();
    error DNAlreadyInitialized();
    error DNNotInitialized();
    error FnSelectorNotRecognized();
    error InsufficientAllowance();
    error InsufficientBalance();
    error InsufficientFee();
    error InvalidIds();
    error InvalidMaxTicketRefresh();
    error InvalidMaxWallet();
    error InvalidPrice();
    error InvalidProbabilityInputs();
    error InvalidTaxValue();
    error InvalidTicketType(uint256 token, uint8 ticketType);
    error InvalidUnit();
    error LinkMirrorContractFailed();
    error MaxWalletExceeded();
    error MirrorAddressIsZero();
    error NotInitialized();
    error NotOwner();
    error RewardTransferFailed();
    error SenderNotMirror();
    error TokenDoesNotExist();
    error TotalSupplyOverflow();
    error TransferCallerNotOwnerNorApproved();
    error TransferFromIncorrectOwner();
    error TransferToZeroAddress();
    error TransferWithLess();
    error UnexpectedRequest();
    event AirnodeSettingsChanged(QRND.AirnodeSettings airnodeSettings);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event ClaimedReward(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 reward
    );
    event MaxTicketRefreshChanged(uint256 amount);
    event MaxWalletChanged(uint256 amount);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event PoolDetailsSet(Trade.PoolDetails details);
    event PrizePoolIncreased(uint256 amountOut);
    event PrizePoolTaxSet(Trade.Tax tax);
    event ProbabilitiesChanged(Tickets.Probabilities probabilities);
    event ProbabilitySnapshot(
        uint256 timestamp,
        Tickets.Probabilities probabilities
    );
    event SeedRequestedForIds(uint256[] tokenIds, uint256 probabilityTimestamp);
    event SeedRequestedForRange(
        uint256 fromId,
        uint256 toId,
        uint256 probabilityTimestamp
    );
    event SkipNFTSet(address indexed owner, bool status);
    event TaxExcludeChanged(address account, bool state);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event UpdatedTotalMinted(uint256 indexed totalMinted);

    fallback() external payable;

    function allowance(address owner, address spender)
    external
    view
    returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function claimReward(uint256 tokenId) external;

    function claimRewards(uint256 startIndex) external;

    function decimals() external pure returns (uint8);

    function fulfillWithIds(bytes32 requestId, bytes memory data) external;

    function fulfillWithRange(bytes32 requestId, bytes memory data) external;

    function getRewardForTicketType(uint8 ticketType)
    external
    view
    returns (uint256);

    function getRewardOf(uint256 tokenId) external view returns (uint256);

    function getRewardsOf(address owner, uint256 startIndex)
    external
    view
    returns (uint256);

    function getRewardsWithProbabilities()
    external
    view
    returns (
        uint256[] memory ticketRewards,
        uint256[] memory ticketProbabilities
    );

    function getSkipNFT(address owner) external view returns (bool);

    function getTicket(uint256 tokenId)
    external
    view
    returns (IMetadataRenderer.Ticket memory);

    function getTicketsOf(address owner, uint256 startIndex)
    external
    view
    returns (IMetadataRenderer.Ticket[] memory tickets);

    function helperContracts()
    external
    view
    returns (address renderer, address referrals);

    function initializePool(address router_, address posManager_, uint24 fee_) external;

    function initializeToken(
        QRND.AirnodeSettings memory airnodeSettings,
        address mirror,
        address renderer,
        address referrals
    ) external;

    function initializeTransfer() external;

    function isExcludedFromTax(address account) external view returns (bool);

    function maxTicketRefresh() external view returns (uint256);

    function maxWallet() external view returns (uint256);

    function mirrorERC721() external view returns (address);

    function name() external pure returns (string memory);

    function owner() external view returns (address);

    function decreasePeriod() external returns (uint256);

    function pool() external view returns (Trade.PoolDetails memory);

    function probabilitiesFor(uint256 timestamp)
    external
    view
    returns (Tickets.Probabilities memory);

    function refreshTickets(uint256[] memory ids) external payable;

    function renounceOwnership() external;

    function requestSettings()
    external
    view
    returns (QRND.AirnodeSettings memory);

    function rescueToken() external;

    function resetInitialPrice() external;

    function setExcludeTax(address account, bool state) external;

    function setHelperContracts(address renderer_, address referrals_) external;

    function setMaxTicketRefresh(uint256 amount) external;

    function setMaxWallet(uint256 amount) external;

    function setPrizePoolTax(Trade.Tax memory tax) external;

    function setProbabilities(Tickets.Probabilities memory p) external;

    function setRequestSettings(QRND.AirnodeSettings memory airnodeSettings)
    external;

    function setSkipNFT(bool skipNFT) external returns (bool);

    function snapshotTimestamps()
    external
    view
    returns (uint256 first, uint256 last);

    function symbol() external pure returns (string memory);

    function syncLottery() external;

    function ticketPrices()
    external
    view
    returns (uint256 current, uint256 initial);

    function ticketProbability(uint8 ticketType)
    external
    view
    returns (uint256);

    function ticketRefreshFee() external view returns (uint256);

    function balanceOfNFT(address owner) external view returns (uint256);

    function totalNFTSupply() external view returns (uint256);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function totalPrizePool() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function prizePoolTax() external view returns (Trade.Tax memory);

    function totalTicketProbabilities() external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function transferNFT(address to, uint256 id) external;

    function transferOwnership(address newOwner) external;

    receive() external payable;
}

interface QRND {
    struct AirnodeSettings {
        address AirnodeRrp;
        address Airnode;
        address SponsorWallet;
        bytes32 EndpointIdUint256;
    }
}

interface Trade {
    struct PoolDetails {
        address Router;
        address Pool;
        address WETH9;
        uint24 Fee;
    }

    struct Tax {
        uint256 Numerator;
        uint256 Denominator;
    }
}

interface Tickets {
    struct Probabilities {
        uint256 Bronze;
        uint256 Silver;
        uint256 Gold;
        uint256 Diamond;
        uint256 Emerald;
    }
}

interface IMetadataRenderer {
    struct Ticket {
        address owner;
        uint256 tokenId;
        uint256 timestamp;
        uint8 ticketType;
    }
}