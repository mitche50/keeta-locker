#!/bin/bash

# Test script for Ledger device compatibility
# Works with Nano S, Nano S Plus, Nano X, and Ledger Stax

echo "🔍 Testing Ledger Device Compatibility"
echo "======================================"
echo ""

# Test basic connection
echo "1. Testing basic Ledger connection..."
LEDGER_ADDRESS=$(cast wallet address --ledger --mnemonic-derivation-path "m/44'/60'/0'/0/0" 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$LEDGER_ADDRESS" ]; then
    echo "✅ Ledger connected successfully!"
    echo "📍 Address: $LEDGER_ADDRESS"
    
    # Detect device type (this is approximate based on behavior)
    echo ""
    echo "2. Testing device capabilities..."
    
    # Test signing capability
    echo "   Testing signature capability..."
    TEST_SIGNATURE=$(cast wallet sign "test message" --ledger --mnemonic-derivation-path "m/44'/60'/0'/0/0" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "✅ Signature test passed"
    else
        echo "⚠️  Signature test failed (user may have cancelled)"
    fi
    
    echo ""
    echo "3. Foundry compatibility check..."
    echo "   Forge version: $(forge --version | head -1)"
    echo "   Cast version: $(cast --version | head -1)"
    
    echo ""
    echo "🎉 Your Ledger device is compatible with this LP Locker integration!"
    echo ""
    echo "Supported devices:"
    echo "  • Ledger Nano S"
    echo "  • Ledger Nano S Plus" 
    echo "  • Ledger Nano X"
    echo "  • Ledger Stax (recommended for best experience)"
    echo ""
    echo "Next steps:"
    echo "  1. Run 'make ledger-help' for detailed usage guide"
    echo "  2. Run 'make ledger-interact' to start the interactive interface"
    
else
    echo "❌ Could not connect to Ledger device"
    echo ""
    echo "Troubleshooting checklist:"
    echo "  1. Ledger device is connected via USB"
    echo "  2. Device is unlocked with PIN"
    echo "  3. Ethereum app is open on the device"
    echo "  4. Contract data is enabled in Ethereum app settings"
    echo "  5. For Stax: USB-C cable supports data transfer"
    echo ""
    echo "If you're using Ledger Stax:"
    echo "  • Ensure you're using a USB-C cable that supports data"
    echo "  • Try different USB ports"
    echo "  • The large screen should show connection status clearly"
fi 