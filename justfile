default:
    @just --list

# Install dependencies for library development
install:
    shards install

# Install dependencies for CLI build
install-cli:
    shards install --shard-file=shard.cli.yml

# Run all tests
test:
    crystal spec

# Run tests with verbose output
test-verbose:
    crystal spec -v

# Run specific test file
test-file file:
    crystal spec {{file}}

# Format Crystal code
fmt:
    crystal tool format

# Check Crystal code formatting
fmt-check:
    crystal tool format --check

# Type check without running
check:
    crystal build --no-codegen src/ralph.cr

# Build CLI (debug)
build: install-cli
    crystal build src/bin/ralph.cr -o bin/ralph

# Build CLI (release)
build-release: install-cli
    crystal build src/bin/ralph.cr -o bin/ralph --release

# Run the CLI (pass arguments after --)
run *args: build
    ./bin/ralph {{args}}

# Clean build artifacts
clean:
    rm -rf bin/ lib/

# Clean and reinstall
clean-all: clean
    rm -f shard.lock
    just install
