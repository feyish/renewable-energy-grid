# Renewable Energy Grid System

A decentralized peer-to-peer renewable energy trading platform built on the Stacks blockchain, enabling local microgrids to trade renewable energy directly.

## Overview

This system creates a trustless marketplace for renewable energy trading within local communities. Participants can sell excess solar, wind, or other renewable energy production directly to neighbors, automatically balancing supply and demand while incentivizing clean energy adoption.

## Core Features

### ⚡ Energy Production Tracking
- Real-time renewable energy production monitoring
- Cryptographic verification of energy sources
- Production capacity management and reporting

### 🔄 Peer-to-Peer Energy Trading
- Direct energy trading between grid participants
- Smart contract-based automatic settlements
- Dynamic pricing based on supply and demand

### ⚖️ Grid Balancing
- Automated supply and demand matching
- Grid stability maintenance algorithms
- Emergency load balancing protocols

## Smart Contract Architecture

### Energy Production
Tracks and verifies renewable energy production:
- Registers renewable energy producers
- Monitors real-time energy generation
- Validates energy source authenticity
- Calculates production rewards and incentives

### Energy Trading
Facilitates direct energy transactions:
- Creates energy trading orders (buy/sell)
- Matches buyers and sellers automatically
- Processes payments and energy transfers
- Manages trading history and settlements

### Grid Balancing
Maintains grid stability and efficiency:
- Monitors grid-wide energy balance
- Triggers automatic demand response
- Coordinates emergency power sharing
- Optimizes energy distribution patterns

## Key Benefits

- **Decentralized Energy**: No central utility company required
- **Community-Owned**: Local control of energy resources
- **Cost Effective**: Lower energy costs through direct trading
- **Green Incentives**: Rewards for renewable energy production
- **Grid Resilience**: Distributed energy network increases reliability
- **Transparency**: All trades and balancing activities are auditable

## Use Cases

1. **Solar Energy Sharing**: Homeowners sell excess solar power to neighbors
2. **Community Wind Farms**: Local wind generation shared across community
3. **Emergency Power**: Automatic power sharing during outages
4. **Peak Load Management**: Intelligent load balancing during high demand
5. **Green Credits**: Trading renewable energy certificates

## Technical Stack

- **Blockchain**: Stacks (Bitcoin Layer 2)
- **Smart Contracts**: Clarity
- **Development**: Clarinet framework
- **Testing**: Vitest + TypeScript

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm
- Renewable energy generation equipment
- Smart meter integration capability

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd renewable-energy-grid
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Check contract syntax:
   ```bash
   clarinet check
   ```

4. Run tests:
   ```bash
   npm test
   ```

## Contract Deployment

Deploy to local devnet:
```bash
clarinet integrate
```

Deploy to testnet:
```bash
clarinet deploy --testnet
```

## Usage Examples

### Register as Energy Producer
```clarity
(contract-call? .energy-production register-producer
  u10000 ;; capacity in watts
  "solar" ;; energy source type
)
```

### Create Energy Trade Order
```clarity
(contract-call? .energy-trading create-sell-order
  u500 ;; amount in kwh
  u50 ;; price per kwh in microSTX
  u144 ;; duration in blocks (~24 hours)
)
```

### Monitor Grid Status
```clarity
(contract-call? .grid-balancing get-grid-status)
```

## Grid Participants

### Energy Producers
- Homeowners with solar panels
- Small wind farm operators
- Community energy cooperatives
- Battery storage operators

### Energy Consumers
- Residential households
- Small businesses
- Community facilities
- Electric vehicle charging stations

### Grid Operators
- Local utility cooperatives
- Community energy managers
- Grid balancing service providers

## Development Roadmap

- [ ] Smart meter integration protocols
- [ ] Real-time energy monitoring dashboard
- [ ] Mobile app for energy trading
- [ ] Integration with national grid systems
- [ ] Carbon credit tokenization
- [ ] Energy storage optimization

## Environmental Impact

- Reduces carbon footprint through renewable incentives
- Decreases transmission losses with local energy trading
- Promotes community energy independence
- Supports distributed renewable energy adoption

## Economic Benefits

- Lower energy costs for consumers
- Additional income for renewable producers
- Reduced infrastructure costs for utilities
- Job creation in local energy sector

## Contributing

We welcome contributions! Please see our contributing guidelines for:
- Hardware integration protocols
- Smart contract improvements
- Testing procedures
- Documentation updates

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions, issues, or feature requests:
- Open an issue on GitHub
- Join our community Discord
- Check our documentation wiki
- Contact local energy cooperative

---

Building the future of distributed renewable energy 🌱⚡