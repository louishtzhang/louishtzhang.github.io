#!/bin/bash

# Script to run Jekyll using x86-64 architecture on Apple Silicon
# This ensures compatibility with Jekyll and all its dependencies

set -e

echo "Setting up x86-64 environment for Jekyll..."

# Force x86-64 architecture
export ARCHFLAGS="-arch x86_64"

# Set up Ruby path
export PATH="/usr/local/opt/ruby@3.2/bin:/Users/zhanghaotian/.gem/ruby/3.2.0/bin:$PATH"

# Set up compiler environment
export SDKROOT=$(xcrun --show-sdk-path)
export CPATH="$SDKROOT/usr/include/c++/v1:$SDKROOT/usr/include"
export CPPFLAGS="-I$SDKROOT/usr/include/c++/v1 -I$SDKROOT/usr/include"
export CXXFLAGS="-I$SDKROOT/usr/include/c++/v1 -I$SDKROOT/usr/include -stdlib=libc++"
export LDFLAGS="-L$SDKROOT/usr/lib"

# Set C++ compiler to use x86-64
export CXX="clang++ -arch x86_64"
export CC="clang -arch x86_64"

# Navigate to site directory
cd "$(dirname "$0")"

echo "Checking bundle..."
# Try to run Jekyll, if it fails, try bundle install first
if ! arch -x86_64 /usr/local/opt/ruby@3.2/bin/bundle exec jekyll --version &> /dev/null; then
    echo "Installing/updating gems..."
    arch -x86_64 /usr/local/opt/ruby@3.2/bin/bundle config set --local path 'vendor/bundle'
    arch -x86_64 /usr/local/opt/ruby@3.2/bin/bundle install || {
        echo "Bundle install encountered issues, but will try to proceed..."
    }
fi

echo "Starting Jekyll server with x86-64 architecture..."
echo "Server will be available at http://localhost:4000"
echo "Press Ctrl+C to stop the server"
echo ""

# Kill any process already using port 4000
lsof -ti:4000 | xargs kill -9 2>/dev/null || true

# Run Jekyll serve with x86-64
arch -x86_64 /usr/local/opt/ruby@3.2/bin/bundle exec jekyll serve --host=0.0.0.0 --port=4000
