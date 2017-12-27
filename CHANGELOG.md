# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/).

## Next release

### Added

### Changed

* CLASSPATH is now set in Cabal hooks before running haddock.

## [0.7.0] - 2017-08-31

### Added

* Plugin option to dump the generated Java to the console or a file.
* Partial support for inner classes. Antiquoted variables and
  quasiquotation results can refer to inner classes now.

### Changed

* Use a compiler plugin to build the bytecode table and to generate
  Java code. We no longer need static pointers to find the bytecode
  at runtime, and we can check at build-time that values are
  marshaled between matching types in Java and Haskell when using
  antiquated variables or the result of quasiquotations. Also, now
  java quasiquotes work inside Template Haskell brackets ([| ... |]).
* Use only the lexer in `language-java`. This defers most parsing
  errors to the `javac` compiler which produces better error
  messages and might support newer syntactic constructs like
  anonymous functions.
* Java checked exceptions are now allowed in java quasiquotes.

### Fixed

* Gradle hooks now produce a correct build-time classpath.

## [0.6.5] - 2017-04-13

## Added

* Exposed loadJavaWrappers.

## [0.6.4] - 2017-04-09

### Fixed

* Fixed handling of repeated antiquotation variables, which in some
  cases was causing a compilation error.

## [0.6.3] - 2017-03-12

### Fixed

* Setting the `CLASSPATH` using Gradle is now fully supported. It was
  previously unusable due to a bug (see #42).

## [0.6.2] - 2017-02-21

* Avoid producing warnings about unused inlinejava_bytecode0 bindings.
* Support type synonyms in variable antiquotation.
* Update lower bounds of jni to 0.3 and jvm to 0.2.

## [0.6.1] - 2016-12-27

* Support passing array objects as arguments / return values.
* More robust mangling of inline class name.

## [0.6.0] - 2016-12-13

### Added

* Can set a custom `CLASSPATH` in `Setup.hs` from Gradle build
  configurations to use when compiling inline expressions.
* GHC 8 compatibility
* Support inline expressions that compile to multiple .class files
  (e.g for anonymous classes and anonymous function literals).

### Changed

* The return type of inline expressions no longer needs
  `Reify`/`Reflect` instances.

### Fixed

* Fix antiquotation: in [java| $obj.foo() |], `obj` is now recognized
  as an antiquotation variable.
* Passing multiple options to the JVM using `withJVM`.

## [0.5.0] - 2016-12-13

### Added

* First release with support for inline Java expressions.

### Changed

* Split lower-level and mid-level bindings into separate packages: jni
  and jvm.
