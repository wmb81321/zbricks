#!/usr/bin/env node

/**
 * Extract deployment addresses and ABIs from forge broadcast files
 * 
 * Usage: node script/extractDeployment.js [chainId]
 * Example: node script/extractDeployment.js 84532
 * 
 * If no chainId provided, uses the latest broadcast folder
 */

const fs = require('fs');
const path = require('path');

// Chain ID mapping
const CHAINS = {
  '84532': 'Base Sepolia',
  '8453': 'Base Mainnet',
  '31337': 'Local'
};

function findLatestBroadcast(chainId) {
  const broadcastDir = path.join(__dirname, '..', 'broadcast', 'DeployAuction.s.sol');
  
  if (!fs.existsSync(broadcastDir)) {
    console.error('❌ No broadcast directory found. Have you deployed yet?');
    process.exit(1);
  }
  
  let targetDir;
  
  if (chainId) {
    targetDir = path.join(broadcastDir, chainId);
  } else {
    // Find latest deployment
    const dirs = fs.readdirSync(broadcastDir)
      .filter(f => fs.statSync(path.join(broadcastDir, f)).isDirectory())
      .sort((a, b) => {
        const statA = fs.statSync(path.join(broadcastDir, a));
        const statB = fs.statSync(path.join(broadcastDir, b));
        return statB.mtime - statA.mtime;
      });
    
    if (dirs.length === 0) {
      console.error('❌ No deployment folders found');
      process.exit(1);
    }
    
    targetDir = path.join(broadcastDir, dirs[0]);
    chainId = dirs[0];
  }
  
  const runLatest = path.join(targetDir, 'run-latest.json');
  
  if (!fs.existsSync(runLatest)) {
    console.error(`❌ No run-latest.json found in ${targetDir}`);
    process.exit(1);
  }
  
  return { file: runLatest, chainId };
}

function extractABI(contractName) {
  const artifactPath = path.join(__dirname, '..', 'out', `${contractName}.sol`, `${contractName}.json`);
  
  if (!fs.existsSync(artifactPath)) {
    console.error(`❌ ABI not found for ${contractName}`);
    return null;
  }
  
  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
  return artifact.abi;
}

function main() {
  const chainId = process.argv[2];
  
  console.log('🔍 Extracting deployment information...\n');
  
  const { file, chainId: detectedChainId } = findLatestBroadcast(chainId);
  const chainName = CHAINS[detectedChainId] || `Chain ${detectedChainId}`;
  
  console.log(`📡 Network: ${chainName} (${detectedChainId})`);
  console.log(`📁 Reading: ${file}\n`);
  
  const broadcast = JSON.parse(fs.readFileSync(file, 'utf8'));
  
  // Extract contract addresses from transactions
  const contracts = {};
  
  for (const tx of broadcast.transactions) {
    if (tx.transactionType === 'CREATE') {
      const contractName = tx.contractName;
      const address = tx.contractAddress;
      
      if (contractName && address) {
        contracts[contractName] = address;
      }
    }
  }
  
  if (Object.keys(contracts).length === 0) {
    console.error('❌ No contracts found in deployment');
    process.exit(1);
  }
  
  console.log('📋 Deployed Contracts:\n');
  for (const [name, address] of Object.entries(contracts)) {
    console.log(`   ${name}: ${address}`);
  }
  console.log('');
  
  // Create deployment info object
  const deploymentInfo = {
    network: chainName,
    chainId: detectedChainId,
    timestamp: new Date().toISOString(),
    contracts: {}
  };
  
  // Add addresses and ABIs
  for (const [name, address] of Object.entries(contracts)) {
    const abi = extractABI(name);
    deploymentInfo.contracts[name] = {
      address,
      abi: abi || []
    };
  }
  
  // Save to deployments folder
  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }
  
  // Create ABI directory (shared across all chains)
  const abiDir = path.join(deploymentsDir, 'abi');
  if (!fs.existsSync(abiDir)) {
    fs.mkdirSync(abiDir);
  }
  
  // Save individual ABI files per contract (only once, chain-agnostic)
  console.log('📦 Extracting ABIs:\n');
  for (const [name, address] of Object.entries(contracts)) {
    const abi = extractABI(name);
    if (abi) {
      const abiFile = path.join(abiDir, `${name}.json`);
      fs.writeFileSync(abiFile, JSON.stringify(abi, null, 2));
      console.log(`   ✓ abi/${name}.json`);
    }
  }
  console.log('');
  
  // Load or create addresses.json
  const addressesFile = path.join(deploymentsDir, 'addresses.json');
  let addressesData = {};
  
  if (fs.existsSync(addressesFile)) {
    addressesData = JSON.parse(fs.readFileSync(addressesFile, 'utf8'));
  }
  
  // Update addresses for this chain
  addressesData[detectedChainId] = {
    chainId: parseInt(detectedChainId),
    chainName,
    timestamp: new Date().toISOString(),
    contracts: contracts
  };
  
  // Save updated addresses.json
  fs.writeFileSync(addressesFile, JSON.stringify(addressesData, null, 2));
  console.log(`✅ Addresses updated in: ${addressesFile}\n`);
  
  // Show current chain info
  console.log(`📋 ${chainName} (${detectedChainId}):\n`);
  for (const [name, address] of Object.entries(contracts)) {
    console.log(`   ${name}: ${address}`);
  }
  console.log('');
  
  console.log('✨ Extraction complete!');
}

try {
  main();
} catch (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}
