const gulp = require('gulp');
const coffeelint = require('gulp-coffeelint');
const mocha = require('gulp-mocha');
const watch = require('gulp-watch');
const yargs = require('yargs');


const handleError = function(err) {
  console.error(err.message);
  return process.exit(1);
};


gulp.task('unit-test', () =>
  gulp.src('tests/*-test.*', {read: false})
    .pipe(mocha({reporter: 'spec', grep: yargs.argv.grep}))
    .on('error', handleError)
);


gulp.task('forgiving-unit-test', () =>
  gulp.src('tests/*-test.*')
    .pipe(mocha({reporter: 'dot', compilers: 'coffee:coffee-script'}))
    .on('error', function(err) {
      if (err.name === 'SyntaxError') {
        if (err) { console.error('You have a syntax error in file: ', err); }
      }
      return this.emit('end');
  })
);


gulp.task('integration-test', function() {
  process.env.PORT = 8001;
  return gulp.src('tests/integration/*-test.*')
    .pipe(mocha({reporter: 'spec', grep: yargs.argv.grep}))
    .on('error', () => handleError)
    .once('end', () => process.exit(0));
});


gulp.task('lint', () =>
  gulp.src(['./*.coffee', './lib/*', './tests/**/*'])
    .pipe(coffeelint({opt: {max_line_length: {value: 1024, level: 'ignore'}}}))
    .pipe(coffeelint.reporter())
    .pipe(coffeelint.reporter('fail'))
    .on('error', () => process.exit(1))
);


gulp.task('forgiving-lint', () =>
  gulp.src(['./*.coffee', './lib/*', './tests/**/*'])
    .pipe(coffeelint({opt: {max_line_length: {value: 1024, level: 'ignore'}}}))
    .pipe(coffeelint.reporter())
    .on('error', function() {
      return this.emit('end');
  })
);


gulp.task('test', ['unit-test', 'integration-test']);


gulp.task('tdd', function() {
  gulp.watch('lib/*', ['forgiving-lint', 'forgiving-unit-test']);
  return gulp.watch('tests/*-test.*', ['forgiving-lint', 'forgiving-unit-test']);
});


gulp.task('default', ['test']);


return;
