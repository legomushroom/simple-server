### vscode-install stats

1. Run `watch -n2 "./sample"` to run the `vscode-install.sh` script continiously. That will output the stats into the `stats.md` file int he root. of the project.
    - 1.a) To run in the "stressed" mode:
        - Run `watch -n2 "./sample.sh stressed"` instead, that will output into the `stats-stressed.md` instead.
        - Run `sudo stress --cpu 2 --vm 1 --vm-bytes 128M --io 2` in the separate terminal window until the watch process completes. You will need to install `stress` util with `apt-get`.
2. Once you have enough data collected, run `node logStats.js` to log stats based on the `stats.md` and/or `stats-pressed.md` files.


## Results

See `___results.md` for results sample. The `__stats.md`  and `__stats-stressed.md` for the raw data sample.