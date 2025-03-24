const { exec } = require('child_process');
const path = require('path');

// Configuration
const config = {
  testFiles: [
    'test_upload_workflow.js',
    'test_chat_workflow.js',
    'test_diagnosis_workflow.js'
  ],
  waitBetweenTests: 5000, // 5 secondes entre chaque test
};

// Fonction pour exécuter un test spécifique
function runTest(testFile) {
  return new Promise((resolve, reject) => {
    const testPath = path.join(__dirname, testFile);
    console.log(`\n\n==========================================`);
    console.log(`Exécution du test: ${testFile}`);
    console.log(`==========================================\n`);
    
    const testProcess = exec(`node ${testPath}`, {
      env: { ...process.env }
    });
    
    testProcess.stdout.pipe(process.stdout);
    testProcess.stderr.pipe(process.stderr);
    
    testProcess.on('close', (code) => {
      if (code === 0) {
        resolve({ file: testFile, success: true });
      } else {
        resolve({ file: testFile, success: false, exitCode: code });
      }
    });
    
    testProcess.on('error', (error) => {
      resolve({ file: testFile, success: false, error: error.message });
    });
  });
}

// Fonction pour attendre un délai
function wait(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Fonction principale pour exécuter tous les tests
async function runAllTests() {
  console.log('=== Exécution de tous les tests d\'intégration ===');
  console.log(`Nombre de tests à exécuter: ${config.testFiles.length}`);
  
  const results = [];
  
  for (const testFile of config.testFiles) {
    // Exécuter le test
    const result = await runTest(testFile);
    results.push(result);
    
    // Attendre entre chaque test
    if (testFile !== config.testFiles[config.testFiles.length - 1]) {
      console.log(`\nAttente de ${config.waitBetweenTests / 1000} secondes avant le prochain test...`);
      await wait(config.waitBetweenTests);
    }
  }
  
  // Afficher le récapitulatif
  console.log('\n\n=== Récapitulatif des tests ===');
  console.log(`Tests exécutés: ${results.length}`);
  
  const successCount = results.filter(r => r.success).length;
  const failedTests = results.filter(r => !r.success);
  
  console.log(`Tests réussis: ${successCount}/${results.length}`);
  
  if (failedTests.length > 0) {
    console.log('\nTests échoués:');
    failedTests.forEach(test => {
      console.log(`- ${test.file} ${test.exitCode ? `(code: ${test.exitCode})` : ''} ${test.error ? `(erreur: ${test.error})` : ''}`);
    });
  }
  
  // Verdict final
  if (successCount === results.length) {
    console.log('\n✅ Tous les tests ont réussi!');
    process.exit(0);
  } else {
    console.log(`\n❌ ${results.length - successCount} test(s) ont échoué`);
    process.exit(1);
  }
}

// Exécution de tous les tests
runAllTests().catch(error => {
  console.error('Erreur lors de l\'exécution des tests:', error);
  process.exit(1);
});
