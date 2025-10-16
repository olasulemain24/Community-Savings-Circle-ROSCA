# 💰 Community Savings Circle (ROSCA) Smart Contract

A decentralized Rotating Savings and Credit Association (ROSCA) built on the Stacks blockchain using Clarity smart contracts. Members contribute regularly to a shared pool, and each cycle one member receives the entire pot! 🔄

## 🚀 Features

- **Circle Creation**: Organizers can create new savings circles with custom parameters
- **Member Management**: Join/leave circles with position-based rotation
- **Automated Cycles**: Time-based cycles with automatic recipient selection
- **Secure Contributions**: STX contributions tracked per cycle
- **Fair Distribution**: Rotating payout system ensures everyone gets their turn
- **Real-time Tracking**: Monitor contributions, balances, and cycle progress

## 📋 How It Works

1. **Create a Circle** 🎯: An organizer sets up a new ROSCA with:
   - Circle name
   - Contribution amount (in microSTX)
   - Cycle duration (in blocks)
   - Maximum number of members

2. **Join the Circle** 👥: Members join the circle and receive a position number

3. **Contribute Each Cycle** 💳: During active cycles, members contribute the set amount

4. **Receive Payouts** 🏆: When it's your turn, claim the accumulated pot for that cycle

5. **Repeat** 🔁: The cycle continues until everyone has received their payout

## 🛠️ Contract Functions

### Public Functions

#### `create-circle`
```clarity
(create-circle (name (string-ascii 50)) (contribution-amount uint) (cycle-duration uint) (max-members uint))
```
Creates a new savings circle. Returns the circle ID.

#### `join-circle`
```clarity
(join-circle (circle-id uint))
```
Join an existing circle as a member.

#### `contribute`
```clarity
(contribute (circle-id uint) (cycle uint))
```
Make your contribution for the current cycle.

#### `claim-cycle-payout`
```clarity
(claim-cycle-payout (circle-id uint) (cycle uint))
```
Claim your payout when it's your turn to receive the pot.

#### `leave-circle`
```clarity
(leave-circle (circle-id uint))
```
Leave a circle (deactivates membership).

### Read-Only Functions

#### `get-circle-stats`
```clarity
(get-circle-stats (circle-id uint))
```
Get comprehensive information about a circle including current cycle, balance, and member count.

#### `get-current-cycle`
```clarity
(get-current-cycle (circle-id uint))
```
Get the current active cycle number for a circle.

#### `get-circle-balance`
```clarity
(get-circle-balance (circle-id uint))
```
Get the current STX balance held by the circle.

## 📖 Usage Example

```clarity
;; Create a new circle
(contract-call? .community-savings-circle create-circle "Friends Circle" u1000000 u144 u5)
;; Creates a circle with 1 STX contribution, 144 block cycles (~1 day), max 5 members

;; Join the circle
(contract-call? .community-savings-circle join-circle u1)

;; Contribute to current cycle
(contract-call? .community-savings-circle contribute u1 u1)

;; Check circle stats
(contract-call? .community-savings-circle get-circle-stats u1)

;; Claim payout when it's your turn
(contract-call? .community-savings-circle claim-cycle-payout u1 u2)
```

## 🔧 Development Setup

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) CLI tool
- Node.js and npm (for testing)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd Community-Savings-Circle-ROSCA
```

2. Install dependencies:
```bash
npm install
```

3. Run tests:
```bash
clarinet test
```

4. Deploy locally:
```bash
clarinet console
```

## 🧪 Testing

The contract includes comprehensive test coverage for:
- Circle creation and management
- Member joining and leaving
- Contribution tracking
- Cycle progression and payouts
- Error handling

Run the test suite:
```bash
npm test
```

## 🔒 Security Features

- **Access Control**: Only authorized members can contribute and claim
- **Amount Validation**: Strict validation of contribution amounts
- **Cycle Management**: Time-based cycles prevent manipulation
- **Balance Protection**: Sufficient balance checks before payouts
- **Member Verification**: Position-based recipient selection

## 📚 Contract Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `ERR-NOT-AUTHORIZED` | u100 | Unauthorized access |
| `ERR-CIRCLE-NOT-FOUND` | u101 | Circle doesn't exist |
| `ERR-ALREADY-MEMBER` | u102 | Already a circle member |
| `ERR-NOT-MEMBER` | u103 | Not a circle member |
| `ERR-CIRCLE-FULL` | u104 | Circle at max capacity |
| `ERR-INVALID-AMOUNT` | u105 | Invalid amount provided |
| `ERR-CYCLE-NOT-ACTIVE` | u106 | Cycle not currently active |
| `ERR-ALREADY-CONTRIBUTED` | u107 | Already contributed this cycle |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'feat: add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🌟 Support

If you find this project helpful, please give it a star! ⭐

For questions or support, please open an issue or reach out to the maintainers.

---

*Built with ❤️ on Stacks blockchain*
