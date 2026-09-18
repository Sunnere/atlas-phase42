#!/bin/bash
cd ~/atlas-phase42

# Replace all hardcoded 8080 references in console logs with PORT variable
sed -i '' "s|http://localhost:8080|http://localhost:\${PORT}|g" 16_railway-backend-phase42.js

# Verify
grep "localhost:" 16_railway-backend-phase42.js | head -3
