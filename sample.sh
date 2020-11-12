#!/bin/bash

TEST_MODE_ARGUMENT=$1

echo "= test mode argument: $TEST_MODE_ARGUMENT"

TEST_MODE_NORMAL='normal'
TEST_MODE_STRESSED='stressed'

OUTPUT_FILENAME_NORMAL='./stats.md'
OUTPUT_FILENAME_STRESSED='./stats-stressed.md'

TEST_MODE=${TEST_MODE_ARGUMENT:-$TEST_MODE_NORMAL}

echo "= test mode: $TEST_MODE"

OUTPUT_FILENAME=$OUTPUT_FILENAME_NORMAL;

if [[ "$TEST_MODE" == "$TEST_MODE_STRESSED" ]]; then
    OUTPUT_FILENAME=$OUTPUT_FILENAME_STRESSED
fi

echo "= output file: $OUTPUT_FILENAME"

START_TIME=$(date +%Y-%m-%d--%H:%M:%S);
echo -e "\n\n-=-=-=-=-=- $START_TIME\n" >> $OUTPUT_FILENAME
./vscode-install.sh "server-linux-x64-web" "e790b931385d72cf5669fcefc51cdf65990efa5d" "da205968-b263-45dd-9893-366c89448e04" "stable" "--install-extension ms-vsonline.vsonline --install-extension GitHub.vscode-pull-request-github --do-not-sync --force" "True" "/home" | grep ">>>" >> $OUTPUT_FILENAME
