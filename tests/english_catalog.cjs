// English rendering for the Node tests that execute isolated QML functions.
const catalog = require('../i18n/en.json');

module.exports = {
    t(key) { return catalog[key] ?? key; },
    number: String,
    format(key, values) {
        return this.t(key).replace(/%([1-9][0-9]*)/g, (match, index) => values[Number(index) - 1] ?? match);
    },
    fileCount(count) {
        return catalog['files.count'][count === 1 ? 'one' : 'other'].replace('%1', count);
    }
};
