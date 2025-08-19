# Health Challenge Rewards 🏃‍♀️💪

A blockchain-based fitness incentive system that rewards users with tokens for completing step count challenges verified by fitness oracles.

## Features ✨

- 🎯 **Challenge Creation**: Set custom step goals with token rewards
- 📱 **Oracle Integration**: Fitness data verification through authorized oracles
- 🏆 **Token Rewards**: Earn FIT tokens for completing challenges
- 👥 **User Registration**: Simple user onboarding system
- ⏰ **Time-bound Challenges**: Challenges with configurable durations
- 📊 **Progress Tracking**: Monitor step completion and earnings

## Quick Start 🚀

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Setup
```bash
clarinet console
```

### Usage Instructions

#### 1. Register as a User 👤
```clarity
(contract-call? .Health-Challenge-Rewards register-user)
```

#### 2. Create a Challenge (Owner/Creator) 🎯
```clarity
(contract-call? .Health-Challenge-Rewards create-challenge u10000 u100 u144)
```
*Creates a challenge: 10,000 steps, 100 FIT token reward, 144 blocks duration*

#### 3. Join a Challenge 🏃
```clarity
(contract-call? .Health-Challenge-Rewards join-challenge u1)
```

#### 4. Oracle Submits Steps 📊
```clarity
(contract-call? .Health-Challenge-Rewards submit-steps 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM u1 u5000)
```
*Oracle submits 5,000 steps for user in challenge 1*

#### 5. Claim Reward 🎉
```clarity
(contract-call? .Health-Challenge-Rewards claim-reward u1)
```

## Smart Contract Functions 📋

### Read-Only Functions
- `get-balance(account)` - Check token balance 💰
- `get-user-info(user)` - Get user registration details 👤
- `get-challenge-info(challenge-id)` - View challenge details 📖
- `get-user-challenge-progress(user, challenge-id)` - Track progress 📈
- `is-challenge-active(challenge-id)` - Check if challenge is ongoing ⏳

### Public Functions
- `register-user()` - Register new user 📝
- `create-challenge(steps, reward, duration)` - Create new challenge 🎯
- `join-challenge(challenge-id)` - Participate in challenge 🏃‍♀️
- `submit-steps(user, challenge-id, steps)` - Oracle step submission 📊
- `claim-reward(challenge-id)` - Claim earned tokens 🏆
- `transfer(amount, sender, recipient, memo)` - Transfer tokens 💸

### Admin Functions 👑
- `add-oracle(oracle)` - Authorize fitness oracle
- `remove-oracle(oracle)` - Remove oracle authorization

## Token Details 🪙

- **Name**: FitnessToken
- **Symbol**: FIT
- **Decimals**: 6
- **Type**: SIP-010 Fungible Token

## Oracle System 🔮

Authorized oracles can submit fitness data to verify step counts. Only contract owner can manage oracle permissions.

## Challenge Mechanics 🎮

1. **Creation**: Users create challenges with step goals and token rewards
2. **Duration**: Challenges have block-based time limits
3. **Participation**: Users join active challenges
4. **Verification**: Oracles submit step data
5. **Completion**: Users claim rewards after reaching goals

## Testing 🧪

Run tests with Clarinet:
```bash
clarinet test
```

## Error Codes ⚠️

- `100`: Owner only function
- `101`: User not registered
- `102`: User already registered
- `103`: Invalid goal parameters
- `104`: Challenge not found
- `105`: Challenge expired
- `106`: Already completed
- `107`: Insufficient steps
- `108`: Unauthorized oracle

## Contributing 🤝

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Submit pull request

## License 📄

MIT License - Build freely! 🚀
