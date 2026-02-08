#!/usr/bin/env node

/**
 * Extract deployment addresses and ABIs from forge broadcast files
 * 
 * Usage: 
 *   node script/extractDeployment.js              - Extract all chains
 *   node script/extractDeployment.js [chainId]    - Extract specific chain
 * 
 * Example: 
 *   node script/extractDeployment.js 84532
 *   node script/extractDeployment.js all
 */

const fs = require('fs');
const path = require('path');

// Chain ID mapping
const CHAINS = {
  '84532': { name: 'Base Sepolia', explorer: 'https://base-sepolia.blockscout.com' },
  '8453': { name: 'Base Mainnet', explorer: 'https://base.blockscout.com' },
  '5042002': { name: 'Arc Testnet', explorer: 'https://testnet.arcscan.app' },
  '5042000': { name: 'Arc Mainnet', explorer: 'TBA' },
  '31337': { name: 'Local', explorer: null }
};

function getAllDeployments() {
  const broadcastDir = path.join(__dirname, '..', 'broadcast', 'DeployFactory.s.sol');
  
  if (!fs.existsSync(broadcastDir)) {
    console.error('❌ No broadcast directory found. Have you deployed yet?');
    return [];
  }
  
  const chainDirs = fs.readdirSync(broadcastDir)
    .filter(f => fs.statSync(path.join(broadcastDir, f)).isDirectory());
  
  return chainDirs.map(chainId => {
    const runLatest = path.join(broadcastDir, chainId, 'run-latest.json');
    if (fs.existsSync(runLatest)) {
      return { chainId, file: runLatest };
    }
    return null;
  }).filter(Boolean);
}

function findLatestBroadcast(chainId) {
  const broadcastDir = path.join(__dirname, '..', 'broadcast', 'DeployFactory.s.sol');
  
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
    console.warn(`⚠️  ABI not found for ${contractName}`);
    return null;
  }
  
  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
  return artifact.abi;
}

function processDeployment(chainId, file) {
  const chainInfo = CHAINS[chainId] || { name: `Chain ${chainId}`, explorer: null };
  
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
  
  return {
    chainId,
    chainName: chainInfo.name,
    explorer: chainInfo.explorer,
    contracts
  };
}
function main() {
  const arg = process.argv[2];
  const extractAll = !arg || arg === 'all';
  
  console.log('🔍 Extracting deployment information...\n');
  
  let deployments = [];
  
  if (extractAll) {
    console.log('📡 Extracting all chain deployments\n');
    const allDeployments = getAllDeployments();
    
    if (allDeployments.length === 0) {
      console.error('❌ No deployments found');
      process.exit(1);
    }
    
    deployments = allDeployments.map(({ chainId, file }) => 
      processDeployment(chainId, file)
    );
  } else {
    const { file, chainId } = findLatestBroadcast(arg);
    deployments = [processDeployment(chainId, file)];
  }
  
  // Display all deployments
  for (const deployment of deployments) {
    console.log(`\n📡 ${deployment.chainName} (Chain ID: ${deployment.chainId})`);
    console.log('─'.repeat(60));
    
    if (Object.keys(deployment.contracts).length === 0) {
      console.log('   No contracts found');
      continue;
    }
    
    for (const [name, address] of Object.entries(deployment.contracts)) {
      console.log(`   ${name.padEnd(20)} ${address}`);
      if (deployment.explorer && deployment.explorer !== 'TBA') {
        console.log(`   ${' '.repeat(20)} ${deployment.explorer}/address/${address}`);
      }
    }
  }
  
  console.log('\n');
  
  // Extract ABIs (once, they're the same across chains)
  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  
  const abiDir = path.join(deploymentsDir, 'abi');
  if (!fs.existsSync(abiDir)) {
    fs.mkdirSync(abiDir, { recursive: true });
  }
  
  // Get unique contract names across all deployments
  const contractNames = new Set();
  deployments.forEach(d => {
    Object.keys(d.contracts).forEach(name => contractNames.add(name));
  });
  
  console.log('📦 Extracting ABIs:\n');
  for (const name of contractNames) {
    const abi = extractABI(name);
    if (abi) {
      const abiFile = path.join(abiDir, `${name}.json`);
      fs.writeFileSync(abiFile, JSON.stringify(abi, null, 2));
      console.log(`   ✓ abi/${name}.json`);
    }
  }
  console.log('');
  
  // Create addresses.json with all chains
  const addressesData = {};
  
  for (const deployment of deployments) {
    const chainInfo = CHAINS[deployment.chainId] || { name: deployment.chainName, explorer: null };
    
    addressesData[deployment.chainId] = {
      chainId: parseInt(deployment.chainId),
      chainName: deployment.chainName,
      explorer: chainInfo.explorer,
      timestamp: new Date().toISOString(),
      contracts: deployment.contracts
    };
  }
  
  const addressesFile = path.join(deploymentsDir, 'addresses.json');
  fs.writeFileSync(addressesFile, JSON.stringify(addressesData, null, 2));
  
  console.log('💾 Saved deployment information:\n');
  console.log(`   ✓ deployments/addresses.json (${Object.keys(addressesData).length} chains)`);
  console.log(`   ✓ deployments/abi/ (${contractNames.size} contracts)\n`);
  
  // Generate markdown documentation
  generateMarkdownDocs(deployments, deploymentsDir);
  
  console.log('✅ Extraction complete!\n');
}

function generateMarkdownDocs(deployments, deploymentsDir) {
  const lines = ['# Deployed Contracts\n'];
  lines.push(`*Last updated: ${new Date().toISOString()}*\n`);
  lines.push('## Networks\n');
  
  for (const deployment of deployments) {
    lines.push(`### ${deployment.chainName} (Chain ID: ${deployment.chainId})\n`);
    
    if (Object.keys(deployment.contracts).length === 0) {
      lines.push('*No contracts deployed*\n');
      continue;
    }
    
    lines.push('| Contract | Address | Explorer |');
    lines.push('|----------|---------|----------|');
    
    for (const [name, address] of Object.entries(deployment.contracts)) {
      let explorerLink = address;
      if (deployment.explorer && deployment.explorer !== 'TBA') {
        explorerLink = `[View](${deployment.explorer}/address/${address})`;
      }
      lines.push(`| **${name}** | \`${address}\` | ${explorerLink} |`);
    }
    
    lines.push('');
  }
  
  lines.push('## ABIs\n');
  lines.push('Contract ABIs are available in [`deployments/abi/`](./abi/) directory:\n');
  
  const contractNames = new Set();
  deployments.forEach(d => {
    Object.keys(d.contracts).forEach(name => contractNames.add(name));
  });
  
  for (const name of Array.from(contractNames).sort()) {
    lines.push(`- [\`${name}.json\`](./abi/${name}.json)`);
  }
  
  lines.push('\n## Usage\n');
  lines.push('```javascript');
  lines.push("const addresses = require('./deployments/addresses.json');");
  lines.push("const houseNFTAbi = require('./deployments/abi/HouseNFT.json');\n");
  lines.push('// Get contract address for specific chain');
  lines.push("const chainId = '84532'; // Base Sepolia");
  lines.push('const houseNFTAddress = addresses[chainId].contracts.HouseNFT;\n');
  lines.push('// Use with ethers.js or viem');
  lines.push('// const contract = new ethers.Contract(houseNFTAddress, houseNFTAbi, provider);');
  lines.push('```\n');
  
  const docsFile = path.join(deploymentsDir, 'README.md');
  fs.writeFileSync(docsFile, lines.join('\n'));
  
  console.log('   ✓ deployments/README.md');
}

try {
  main();
} catch (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}

