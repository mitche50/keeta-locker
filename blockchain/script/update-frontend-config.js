#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Read the latest deployment from broadcast files
function getLatestDeployment(chainId) {
    const broadcastDir = path.join(__dirname, '..', 'broadcast', 'Deploy.s.sol', chainId.toString());

    if (!fs.existsSync(broadcastDir)) {
        console.log(`No deployment found for chain ${chainId}`);
        return null;
    }

    const runLatestPath = path.join(broadcastDir, 'run-latest.json');
    if (!fs.existsSync(runLatestPath)) {
        console.log(`No run-latest.json found for chain ${chainId}`);
        return null;
    }

    const deployment = JSON.parse(fs.readFileSync(runLatestPath, 'utf8'));
    return deployment;
}

// Extract contract addresses from deployment
function extractAddresses(deployment) {
    const addresses = {};

    if (deployment.transactions) {
        deployment.transactions.forEach(tx => {
            if (tx.contractName === 'MockERC20') {
                addresses.lpToken = tx.contractAddress;
            } else if (tx.contractName === 'LPLocker') {
                addresses.lpLocker = tx.contractAddress;
            }
        });
    }

    return addresses;
}

// Update frontend config
function updateFrontendConfig(chainId, addresses) {
    const configPath = path.join(__dirname, '..', '..', 'frontend', 'src', 'config.ts');

    if (!fs.existsSync(configPath)) {
        console.error('Frontend config file not found');
        return false;
    }

    let config = fs.readFileSync(configPath, 'utf8');

    // Update the specific chain's addresses
    const chainKey = `[${chainId}]`;
    const regex = new RegExp(`(${chainKey}\\s*:\\s*{[^}]*lpLocker:\\s*")[^"]*(".*?lpToken:\\s*")[^"]*(")`);

    if (addresses.lpLocker && addresses.lpToken) {
        config = config.replace(regex, `$1${addresses.lpLocker}$2${addresses.lpToken}$3`);

        fs.writeFileSync(configPath, config);
        console.log(`✅ Updated frontend config for chain ${chainId}:`);
        console.log(`   LPLocker: ${addresses.lpLocker}`);
        console.log(`   LP Token: ${addresses.lpToken}`);
        return true;
    }

    return false;
}

// Main function
function main() {
    const chainId = process.argv[2] || '31337';

    console.log(`Updating frontend config for chain ${chainId}...`);

    const deployment = getLatestDeployment(chainId);
    if (!deployment) {
        console.error('No deployment data found');
        process.exit(1);
    }

    const addresses = extractAddresses(deployment);
    if (!addresses.lpLocker || !addresses.lpToken) {
        console.error('Could not extract contract addresses from deployment');
        process.exit(1);
    }

    const success = updateFrontendConfig(chainId, addresses);
    if (!success) {
        console.error('Failed to update frontend config');
        process.exit(1);
    }

    console.log('✅ Frontend config updated successfully!');
}

if (require.main === module) {
    main();
}

module.exports = { getLatestDeployment, extractAddresses, updateFrontendConfig }; 