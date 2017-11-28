'use strict';
var runBinary = require('./run_binary')
var commandName = require('./command_name')
const exec = require('child_process').exec

module.exports.create = (event, context, callback) => {
  exec(commandName(context, event, 'create'), (err, stdout, stderr) => {
    callback(null, runBinary('create', 'pizzas', err, stdout, stderr, event));
  });
};

module.exports.read = (event, context, callback) => {
  exec(commandName(context, event, 'read'), (err, stdout, stderr) => {
    callback(null, runBinary('read', 'pizzas', err, stdout, stderr, event));
  });
};

module.exports.update = (event, context, callback) => {
  exec(commandName(context, event, 'update'), (err, stdout, stderr) => {
    callback(null, runBinary('update', 'pizzas', err, stdout, stderr, event));
  });
};

module.exports.delete = (event, context, callback) => {
  exec(commandName(context, event['id'], 'delete'), (err, stdout, stderr) => {
    callback(null, runBinary('delete', 'pizzas', err, stdout, stderr, event['id']));
  });
};
