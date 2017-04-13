'use strict';
const exec = require('child_process').exec

module.exports.create = (event, context, callback) => {
  var command = "package/osx/app -m #<Hecks::Domain::DomainBuilder::DomainModule:0x007ff1b70d06c8> -c create -d '" + JSON.stringify(event) + "'"

  exec(command, (err, stdout, stderr) => {
    if (err) { console.error(err); return }
    var result = JSON.parse(stdout)
    console.error(stderr)
    const response = {
      statusCode: Object.keys(result.errors).length > 0 ? 500 : 200,
      body: { message: create command called on the #<Hecks::Domain::DomainBuilder::DomainModule:0x007ff1b70d06c8> module', input: event, result: result, errors: result['errors']}
    };
    callback(null, response);
  });
};
