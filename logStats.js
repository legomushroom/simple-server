const fs = require('fs');
const path = require('path');

const stats = require("stats-lite");

const logStats = (content, caption) => {
    const regex = new RegExp(`>>> ${caption}: \\d+\\.\\d+$`, 'gim');
    const matches = content.match(regex);

    if (!matches) {
        throw new Error(`No matches found for ${caption}.`);
    }

    const timings = matches.map((matchString) => {
        //console.log(`matchString: ${matchString}`);
        const result = matchString.match(/\d+\.\d+$/);
        //console.log(`matchString result: ${result}`);

        return parseFloat(result);
    });

    console.log('');
    console.log(`${caption}:`);
    console.log('');

    console.log(`  - 95th percentile: ${stats.percentile(timings, 0.95)}`);
    console.log(`  - mean: ${stats.mean(timings)}`);
    console.log(`  - median: ${stats.median(timings)}`);
    console.log(`  - standard deviation: ${stats.stdev(timings)} / ${stats.sampleStdev(timings)}`);

    console.log(`  - min: ${Math.min(...timings)}`);
    console.log(`  - max: ${Math.max(...timings)}`);

    console.log('');

    //console.log(`[${caption}] sum: ${stats.sum(timings)}`);
    //console.log(`[${caption}] mode: ${stats.mode(timings)}`);
    //console.log(`[${caption}] variance: ${stats.variance(timings)}`);
}

const processFile = (inputFile) => {
    console.log(`\n---- ${inputFile}:`)

    try {
        const content = fs.readFileSync(inputFile, 'utf8');
    } catch(e) {
        console.warn(`No "${inputFile}" found.`);
        return;
    }

    logStats(content, 'server installation time');
    logStats(content, 'vscode server start time');
    logStats(content, 'extension installation time');
    logStats(content, 'total time');
}

processFile(path.join(__dirname, './stats.md'));
processFile(path.join(__dirname, './stats-stressed.md')); 
