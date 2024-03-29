# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

install: solc update npm
# dapp deps
update:; dapp update
# npm deps for linting etc.
npm:; yarn install
# install solc version
solc:; nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_0_8_11

# Build & test & deploy
build    :; dapp build
clean    :; dapp clean
debug    :; ./scripts/run.sh local "dapp debug"
debug-tx :; ./scripts/run.sh $(network) "seth run-tx $(tx) --source out/dapp.sol.json --debug"
lint     :; yarn run lint
size     :; ./scripts/contract-size.sh ${contract}
test     :; ./scripts/run.sh mainnet "dapp test --ffi --verbosity 1 --rpc"
