// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Minimal read interface for the SPACE ID "AI" Agent ID registry (ERC-721).
interface IAgentIDRegistryV3 {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentCheckInV3
/// @notice Daily check-in for Binance Agentic Wallet Agent ID holders on BNB Chain,
///         with soulbound streak badges (ERC-721) that boost check-in points.
/// @dev The contract holds no funds, has no owner and no admin powers, and never
///      moves anyone's assets. Badges are soulbound: they can be minted by checking
///      in, and they can never be transferred or sold. Points are a leaderboard
///      score only, not a token, and carry no promise of value.
///      On BNB Chain mainnet the Agent ID registry is
///      0x60b9262456de011f7d15a54cdd8c48baaa8b022f.
contract AgentCheckInV3 {
    IAgentIDRegistryV3 public immutable agentIdRegistry;

    // ---------------- check-in state ----------------
    struct Stats {
        uint256 lastCheckInDay;
        uint256 currentStreak;
        uint256 bestStreak;
        uint256 totalCheckIns;
        uint256 points;
    }

    mapping(address => Stats) private _stats;
    address[] private _users;
    mapping(address => bool) private _known;

    uint256 public totalCheckIns;
    mapping(uint256 => uint256) public checkInsOnDay;

    // ---------------- referral state ----------------
    /// @notice Hard cap on how many users one referrer can earn from.
    uint256 public constant MAX_REFERRALS = 5;
    /// @notice The referrer bound at a user's first check-in (zero = none).
    mapping(address => address) public referrerOf;
    mapping(address => address[]) private _referrals;
    /// @notice Total points a referrer has earned from referrals.
    mapping(address => uint256) public referralEarnings;

    // ---------------- badge state (soulbound ERC-721) ----------------
    string public constant name = "Agent Check-In Badge";
    string public constant symbol = "ACIB";

    // tier: 1 Bronze (7d), 2 Silver (30d), 3 Gold (100d), 4 Diamond (365d)
    mapping(address => mapping(uint8 => bool)) public badgeClaimed;
    mapping(address => uint8) public bestTier;
    mapping(uint256 => address) private _badgeOwner;
    mapping(uint256 => uint8) private _badgeTier;
    mapping(address => uint256) private _badgeCount;
    uint256 private _nextBadgeId = 1;

    event CheckedIn(address indexed user, uint256 indexed day, uint256 streak, uint256 earned, uint256 totalPoints);
    event BadgeMinted(address indexed user, uint8 tier, uint256 tokenId);
    event ReferralBound(address indexed user, address indexed referrer);
    event ReferralReward(address indexed referrer, address indexed fromUser, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    error NoAgentID();
    error AlreadyCheckedInToday();
    error InvalidLimit();
    error Soulbound();

    constructor(address registry) {
        agentIdRegistry = IAgentIDRegistryV3(registry);
    }

    // ---------------- helpers ----------------
    function today() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    function hasAgentID(address user) public view returns (bool) {
        return agentIdRegistry.balanceOf(user) > 0;
    }

    function hasCheckedInToday(address user) public view returns (bool) {
        return _stats[user].totalCheckIns > 0 && _stats[user].lastCheckInDay == today();
    }

    function canCheckIn(address user) public view returns (bool) {
        return hasAgentID(user) && !hasCheckedInToday(user);
    }

    function currentStreakOf(address user) public view returns (uint256) {
        Stats storage s = _stats[user];
        if (s.totalCheckIns == 0) return 0;
        if (s.lastCheckInDay == today() || s.lastCheckInDay == today() - 1) return s.currentStreak;
        return 0;
    }

    function getStats(address user) public view returns (
        uint256 totalCheckIns_,
        uint256 currentStreak_,
        uint256 bestStreak_,
        uint256 points_,
        uint256 lastCheckInDay_
    ) {
        Stats storage s = _stats[user];
        return (s.totalCheckIns, currentStreakOf(user), s.bestStreak, s.points, s.lastCheckInDay);
    }

    function totalAgents() public view returns (uint256) {
        return _users.length;
    }

    /// @notice Point boost in percent granted by the best badge tier held.
    function boostPercentOf(address user) public view returns (uint256) {
        uint8 t = bestTier[user];
        if (t == 1) return 10;
        if (t == 2) return 25;
        if (t == 3) return 50;
        if (t == 4) return 100;
        return 0;
    }

    function tierThreshold(uint8 tier) public pure returns (uint256) {
        if (tier == 1) return 7;
        if (tier == 2) return 30;
        if (tier == 3) return 100;
        if (tier == 4) return 365;
        return 0;
    }

    function tierName(uint8 tier) public pure returns (string memory) {
        if (tier == 1) return "Bronze";
        if (tier == 2) return "Silver";
        if (tier == 3) return "Gold";
        if (tier == 4) return "Diamond";
        return "";
    }

    // ---------------- check-in ----------------
    /// @notice Check in for today without a referrer.
    function checkIn() external {
        _checkIn(address(0));
    }

    /// @notice Check in for today. On your first ever check-in, `referrer` is
    ///         bound permanently if they are an existing user with a free slot.
    function checkIn(address referrer) external {
        _checkIn(referrer);
    }

    /// @notice How many referrals a user has bound so far.
    function referralCountOf(address user) public view returns (uint256) {
        return _referrals[user].length;
    }

    /// @notice The list of users bound to this referrer.
    function referralsOf(address user) public view returns (address[] memory) {
        return _referrals[user];
    }

    function _checkIn(address referrer) internal {
        if (!hasAgentID(msg.sender)) revert NoAgentID();
        uint256 day = today();
        Stats storage s = _stats[msg.sender];
        if (s.totalCheckIns > 0 && s.lastCheckInDay == day) revert AlreadyCheckedInToday();

        // Bind the referrer once, at the first check-in. An invalid referrer
        // (self, unknown user, or a full 5 slots) is ignored, never blocking.
        if (s.totalCheckIns == 0 && referrer != address(0) && referrer != msg.sender
            && _known[referrer] && _referrals[referrer].length < MAX_REFERRALS) {
            referrerOf[msg.sender] = referrer;
            _referrals[referrer].push(msg.sender);
            emit ReferralBound(msg.sender, referrer);
        }

        uint256 streak;
        if (s.totalCheckIns > 0 && s.lastCheckInDay == day - 1) {
            streak = s.currentStreak + 1;
        } else {
            streak = 1;
        }

        uint256 bonus = streak - 1;
        if (bonus > 20) bonus = 20;
        uint256 base = 10 + bonus;
        uint256 earned = (base * (100 + boostPercentOf(msg.sender))) / 100;

        s.lastCheckInDay = day;
        s.currentStreak = streak;
        if (streak > s.bestStreak) s.bestStreak = streak;
        s.totalCheckIns += 1;
        s.points += earned;

        if (!_known[msg.sender]) {
            _known[msg.sender] = true;
            _users.push(msg.sender);
        }
        totalCheckIns += 1;
        checkInsOnDay[day] += 1;

        emit CheckedIn(msg.sender, day, streak, earned, s.points);

        // The referrer earns 10% of whatever this check-in earned.
        address ref = referrerOf[msg.sender];
        if (ref != address(0)) {
            uint256 reward = earned / 10;
            if (reward > 0) {
                _stats[ref].points += reward;
                referralEarnings[ref] += reward;
                emit ReferralReward(ref, msg.sender, reward);
            }
        }

        // Auto-mint the badge the moment a streak threshold is first reached.
        for (uint8 tier = 1; tier <= 4; tier++) {
            if (streak == tierThreshold(tier) && !badgeClaimed[msg.sender][tier]) {
                badgeClaimed[msg.sender][tier] = true;
                if (tier > bestTier[msg.sender]) bestTier[msg.sender] = tier;
                uint256 id = _nextBadgeId++;
                _badgeOwner[id] = msg.sender;
                _badgeTier[id] = tier;
                _badgeCount[msg.sender] += 1;
                emit Transfer(address(0), msg.sender, id);
                emit BadgeMinted(msg.sender, tier, id);
            }
        }
    }

    // ---------------- leaderboard ----------------
    function getLeaderboard(uint256 limit) external view returns (
        address[] memory users,
        uint256[] memory points,
        uint256[] memory checkIns,
        uint256[] memory bestStreaks
    ) {
        if (limit == 0 || limit > 50) revert InvalidLimit();
        uint256 n = _users.length;
        uint256 count = limit < n ? limit : n;
        users = new address[](count);
        points = new uint256[](count);
        checkIns = new uint256[](count);
        bestStreaks = new uint256[](count);
        bool[] memory taken = new bool[](n);
        for (uint256 k = 0; k < count; k++) {
            uint256 bestIdx = 0;
            uint256 bestPoints = 0;
            bool found = false;
            for (uint256 i = 0; i < n; i++) {
                if (taken[i]) continue;
                uint256 p = _stats[_users[i]].points;
                if (!found || p > bestPoints) {
                    found = true;
                    bestPoints = p;
                    bestIdx = i;
                }
            }
            taken[bestIdx] = true;
            address u = _users[bestIdx];
            users[k] = u;
            points[k] = _stats[u].points;
            checkIns[k] = _stats[u].totalCheckIns;
            bestStreaks[k] = _stats[u].bestStreak;
        }
    }

    // ---------------- ERC-721 (soulbound) ----------------
    function balanceOf(address owner) external view returns (uint256) {
        return _badgeCount[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address o = _badgeOwner[tokenId];
        require(o != address(0), "nonexistent");
        return o;
    }

    function tokenTier(uint256 tokenId) external view returns (uint8) {
        require(_badgeOwner[tokenId] != address(0), "nonexistent");
        return _badgeTier[tokenId];
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_badgeOwner[tokenId] != address(0), "nonexistent");
        uint8 tier = _badgeTier[tokenId];
        string memory tName = tierName(tier);
        string memory color = tier == 1 ? "#cd7f32" : tier == 2 ? "#c0c0c0" : tier == 3 ? "#ffd700" : "#7ee7f5";
        string memory svg = string(abi.encodePacked(
            "<svg xmlns='http://www.w3.org/2000/svg' width='400' height='400'>",
            "<rect width='400' height='400' fill='#0b0e17'/>",
            "<circle cx='200' cy='170' r='95' fill='", color, "'/>",
            "<text x='200' y='185' font-size='44' text-anchor='middle' fill='#0b0e17' font-family='sans-serif' font-weight='bold'>", tName, "</text>",
            "<text x='200' y='320' font-size='24' text-anchor='middle' fill='#ffffff' font-family='sans-serif'>Agent Check-In</text>",
            "<text x='200' y='352' font-size='18' text-anchor='middle' fill='#9aa4b2' font-family='sans-serif'>Streak Badge</text>",
            "</svg>"));
        string memory json = string(abi.encodePacked(
            '{"name":"Agent Check-In ', tName, ' Badge",',
            '"description":"Soulbound badge for a ', tName, ' check-in streak in Agent Check-In, the daily check-in dApp for Agent ID holders on BNB Chain.",',
            '"image":"data:image/svg+xml;utf8,', svg, '",',
            '"attributes":[{"trait_type":"Tier","value":"', tName, '"},',
            '{"trait_type":"Streak Days","value":', _toString(tierThreshold(tier)), '}]}'));
        return string(abi.encodePacked("data:application/json;utf8,", json));
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == 0x80ac58cd || interfaceId == 0x5b5e139f;
    }

    // Soulbound: every transfer path reverts.
    function transferFrom(address, address, uint256) external pure { revert Soulbound(); }
    function safeTransferFrom(address, address, uint256) external pure { revert Soulbound(); }
    function safeTransferFrom(address, address, uint256, bytes calldata) external pure { revert Soulbound(); }
    function approve(address, uint256) external pure { revert Soulbound(); }
    function setApprovalForAll(address, bool) external pure { revert Soulbound(); }
    function getApproved(uint256) external pure returns (address) { return address(0); }
    function isApprovedForAll(address, address) external pure returns (bool) { return false; }

    function _toString(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 len;
        uint256 t = v;
        while (t > 0) { len++; t /= 10; }
        bytes memory b = new bytes(len);
        while (v > 0) { b[--len] = bytes1(uint8(48 + (v % 10))); v /= 10; }
        return string(b);
    }
}
