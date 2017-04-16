'use strict';
var runBinary = require('./run_binary')
var commandName = require('./command_name')
const exec = require('child_process').exec

module.exports.create = (event, context, callback) => {
  exec(commandName(context, event, 'create'), (err, stdout, stderr) => {
    callback(null, runBinary('create', 'orders', err, stdout, stderr, event));
  });
};
