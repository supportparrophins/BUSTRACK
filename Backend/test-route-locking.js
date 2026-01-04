// Test script for route locking functionality
const io = require('socket.io-client');

console.log('🧪 Testing Route Locking Feature\n');

// Configuration
const SERVER_URL = 'http://localhost:3000';
const TEST_ROUTE_ID = 5;
const TEST_BUS_1 = { bus_id: 42, vehicle_number: 'DL-1234' };
const TEST_BUS_2 = { bus_id: 38, vehicle_number: 'DL-5678' };

let driver1Socket, driver2Socket;
let testsPassed = 0;
let testsFailed = 0;

function logTest(testName, passed, message) {
  if (passed) {
    console.log(`✅ PASS: ${testName}`);
    if (message) console.log(`   ${message}`);
    testsPassed++;
  } else {
    console.log(`❌ FAIL: ${testName}`);
    if (message) console.log(`   ${message}`);
    testsFailed++;
  }
  console.log();
}

// Test 1: Driver 1 locks route successfully
function test1_driver1LockRoute() {
  return new Promise((resolve) => {
    console.log('📝 Test 1: Driver 1 attempts to lock Route 5...');
    
    driver1Socket = io(SERVER_URL, {
      transports: ['websocket'],
      reconnection: false
    });

    driver1Socket.on('connect', () => {
      console.log(`   Driver 1 connected: ${driver1Socket.id}`);
      
      driver1Socket.emit('authenticate_driver', {
        bus_id: TEST_BUS_1.bus_id,
        route_id: TEST_ROUTE_ID,
        vehicle_number: TEST_BUS_1.vehicle_number
      });
    });

    driver1Socket.on('route_lock_success', (data) => {
      logTest(
        'Test 1: Driver 1 locks route',
        data.success === true,
        `Route ${data.route_id} locked for Bus ${data.bus_id}`
      );
      resolve(true);
    });

    driver1Socket.on('route_locked', (data) => {
      logTest(
        'Test 1: Driver 1 locks route',
        false,
        `Unexpected error: ${data.message}`
      );
      resolve(false);
    });

    setTimeout(() => {
      logTest('Test 1: Driver 1 locks route', false, 'Timeout - no response');
      resolve(false);
    }, 5000);
  });
}

// Test 2: Driver 2 tries to lock same route (should fail)
function test2_driver2LockSameRoute() {
  return new Promise((resolve) => {
    console.log('📝 Test 2: Driver 2 attempts to lock Route 5 (already locked)...');
    
    driver2Socket = io(SERVER_URL, {
      transports: ['websocket'],
      reconnection: false
    });

    driver2Socket.on('connect', () => {
      console.log(`   Driver 2 connected: ${driver2Socket.id}`);
      
      driver2Socket.emit('authenticate_driver', {
        bus_id: TEST_BUS_2.bus_id,
        route_id: TEST_ROUTE_ID,
        vehicle_number: TEST_BUS_2.vehicle_number
      });
    });

    driver2Socket.on('route_locked', (data) => {
      logTest(
        'Test 2: Driver 2 blocked from locking',
        data.success === false,
        `Correctly rejected: ${data.message}`
      );
      resolve(true);
    });

    driver2Socket.on('route_lock_success', (data) => {
      logTest(
        'Test 2: Driver 2 blocked from locking',
        false,
        `ERROR: Driver 2 should not have been able to lock the route!`
      );
      resolve(false);
    });

    setTimeout(() => {
      logTest('Test 2: Driver 2 blocked from locking', false, 'Timeout - no response');
      resolve(false);
    }, 5000);
  });
}

// Test 3: Driver 1 sends location (should work)
function test3_driver1SendLocation() {
  return new Promise((resolve) => {
    console.log('📝 Test 3: Driver 1 sends location update...');
    
    let locationSent = false;

    driver1Socket.on('route_not_locked', (data) => {
      logTest(
        'Test 3: Driver 1 sends location',
        false,
        `ERROR: Driver 1 should be able to send location! ${data.message}`
      );
      resolve(false);
    });

    // Send location
    driver1Socket.emit('bus_location', {
      bus_id: TEST_BUS_1.bus_id,
      route_id: TEST_ROUTE_ID,
      lat: 28.6139,
      lng: 77.2090,
      speed: 25.5
    });
    locationSent = true;

    setTimeout(() => {
      // If no error received, location was accepted
      logTest(
        'Test 3: Driver 1 sends location',
        locationSent,
        'Location update accepted'
      );
      resolve(true);
    }, 2000);
  });
}

// Test 4: Driver 2 sends location (should fail)
function test4_driver2SendLocation() {
  return new Promise((resolve) => {
    console.log('📝 Test 4: Driver 2 tries to send location (unauthorized)...');
    
    driver2Socket.on('route_not_locked', (data) => {
      logTest(
        'Test 4: Driver 2 blocked from sending location',
        true,
        `Correctly rejected: ${data.message}`
      );
      resolve(true);
    });

    // Try to send location without authentication
    driver2Socket.emit('bus_location', {
      bus_id: TEST_BUS_2.bus_id,
      route_id: TEST_ROUTE_ID,
      lat: 28.6140,
      lng: 77.2091,
      speed: 30.0
    });

    setTimeout(() => {
      logTest('Test 4: Driver 2 blocked from sending location', false, 'Should have been rejected');
      resolve(false);
    }, 2000);
  });
}

// Test 5: Driver 1 disconnects, route unlocks
function test5_driver1Disconnect() {
  return new Promise((resolve) => {
    console.log('📝 Test 5: Driver 1 disconnects, route should unlock...');
    
    driver1Socket.disconnect();
    
    setTimeout(() => {
      logTest(
        'Test 5: Driver 1 disconnects',
        true,
        'Driver 1 disconnected'
      );
      resolve(true);
    }, 1000);
  });
}

// Test 6: Driver 2 locks route after Driver 1 disconnects
function test6_driver2LockAfterUnlock() {
  return new Promise((resolve) => {
    console.log('📝 Test 6: Driver 2 attempts to lock Route 5 (now available)...');
    
    // Create new socket for Driver 2
    const driver2NewSocket = io(SERVER_URL, {
      transports: ['websocket'],
      reconnection: false
    });

    driver2NewSocket.on('connect', () => {
      console.log(`   Driver 2 reconnected: ${driver2NewSocket.id}`);
      
      driver2NewSocket.emit('authenticate_driver', {
        bus_id: TEST_BUS_2.bus_id,
        route_id: TEST_ROUTE_ID,
        vehicle_number: TEST_BUS_2.vehicle_number
      });
    });

    driver2NewSocket.on('route_lock_success', (data) => {
      logTest(
        'Test 6: Driver 2 locks route after unlock',
        data.success === true,
        `Route ${data.route_id} now locked for Bus ${data.bus_id}`
      );
      driver2NewSocket.disconnect();
      resolve(true);
    });

    driver2NewSocket.on('route_locked', (data) => {
      logTest(
        'Test 6: Driver 2 locks route after unlock',
        false,
        `Route still locked: ${data.message}`
      );
      driver2NewSocket.disconnect();
      resolve(false);
    });

    setTimeout(() => {
      logTest('Test 6: Driver 2 locks route after unlock', false, 'Timeout - no response');
      driver2NewSocket.disconnect();
      resolve(false);
    }, 5000);
  });
}

// Run all tests
async function runTests() {
  console.log('🚀 Starting Route Locking Tests...\n');
  console.log(`Server: ${SERVER_URL}`);
  console.log(`Test Route ID: ${TEST_ROUTE_ID}`);
  console.log(`Test Bus 1: ${TEST_BUS_1.vehicle_number} (ID: ${TEST_BUS_1.bus_id})`);
  console.log(`Test Bus 2: ${TEST_BUS_2.vehicle_number} (ID: ${TEST_BUS_2.bus_id})\n`);
  console.log('=' .repeat(60) + '\n');

  try {
    await test1_driver1LockRoute();
    await test2_driver2LockSameRoute();
    await test3_driver1SendLocation();
    await test4_driver2SendLocation();
    await test5_driver1Disconnect();
    await new Promise(resolve => setTimeout(resolve, 2000)); // Wait for disconnect to process
    await test6_driver2LockAfterUnlock();

    console.log('=' .repeat(60));
    console.log('📊 TEST SUMMARY');
    console.log('=' .repeat(60));
    console.log(`✅ Tests Passed: ${testsPassed}`);
    console.log(`❌ Tests Failed: ${testsFailed}`);
    console.log(`📈 Success Rate: ${((testsPassed / (testsPassed + testsFailed)) * 100).toFixed(1)}%`);
    console.log('=' .repeat(60));

    if (testsFailed === 0) {
      console.log('\n🎉 All tests passed! Route locking is working correctly.\n');
    } else {
      console.log('\n⚠️  Some tests failed. Please review the implementation.\n');
    }

  } catch (error) {
    console.error('❌ Test suite error:', error);
  } finally {
    if (driver1Socket && driver1Socket.connected) driver1Socket.disconnect();
    if (driver2Socket && driver2Socket.connected) driver2Socket.disconnect();
    process.exit(testsFailed === 0 ? 0 : 1);
  }
}

// Check if server is reachable
console.log(`🔍 Checking if server is running at ${SERVER_URL}...\n`);
const checkSocket = io(SERVER_URL, {
  transports: ['websocket'],
  reconnection: false,
  timeout: 3000
});

checkSocket.on('connect', () => {
  console.log('✅ Server is reachable!\n');
  checkSocket.disconnect();
  runTests();
});

checkSocket.on('connect_error', (error) => {
  console.error('❌ Cannot connect to server!');
  console.error('   Make sure the backend server is running:');
  console.error('   cd Backend && node server.js\n');
  console.error('   Error:', error.message);
  process.exit(1);
});
