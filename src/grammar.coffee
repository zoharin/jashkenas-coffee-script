# The CoffeeScript parser is generated by [Jison](http://github.com/zaach/jison)
# from this grammar file. Jison is a bottom-up parser generator, similar in
# style to [Bison](http://www.gnu.org/software/bison), implemented in JavaScript.
# It can recognize [LALR(1), LR(0), SLR(1), and LR(1)](http://en.wikipedia.org/wiki/LR_grammar)
# type grammars. To create the Jison parser, we list the pattern to match
# on the left-hand side, and the action to take (usually the creation of syntax
# tree nodes) on the right. As the parser runs, it
# shifts tokens from our token stream, from left to right, and
# [attempts to match](http://en.wikipedia.org/wiki/Bottom-up_parsing)
# the token sequence against the rules below. When a match can be made, it
# reduces into the [nonterminal](http://en.wikipedia.org/wiki/Terminal_and_nonterminal_symbols)
# (the enclosing name at the top), and we proceed from there.
#
# If you run the `cake build:parser` command, Jison constructs a parse table
# from our rules and saves it into `lib/parser.js`.

# The only dependency is on the **Jison.Parser**.
{Parser} = require 'jison'

# Jison DSL
# ---------

# Since we're going to be wrapped in a function by Jison in any case, if our
# action immediately returns a value, we can optimize by removing the function
# wrapper and just returning the value directly.
unwrap = /^function\s*\(\)\s*\{\s*return\s*([\s\S]*);\s*\}/

# Our handy DSL for Jison grammar generation, thanks to
# [Tim Caswell](http://github.com/creationix). For every rule in the grammar,
# we pass the pattern-defining string, the action to run, and extra options,
# optionally. If no action is specified, we simply pass the value of the
# previous nonterminal.
o = (patternString, action, options) ->
  patternString = patternString.replace /\s{2,}/g, ' '
  return [patternString, '$$ = $1;', options] unless action
  action = if match = unwrap.exec action then match[1] else "(#{action}())"
  action = action.replace /\bnew /g, '$&yy.'
  action = action.replace /\b(?:Expressions\.wrap|extend)\b/g, 'yy.$&'
  [patternString, "$$ = #{action};", options]

# Grammatical Rules
# -----------------

# In all of the rules that follow, you'll see the name of the nonterminal as
# the key to a list of alternative matches. With each match's action, the
# dollar-sign variables are provided by Jison as references to the value of
# their numeric position, so in this rule:
#
#     "Expression UNLESS Expression"
#
# `$1` would be the value of the first `Expression`, `$2` would be the token
# for the `UNLESS` terminal, and `$3` would be the value of the second
# `Expression`.
grammar =

  # The **Root** is the top-level node in the syntax tree. Since we parse bottom-up,
  # all parsing must end here.
  Root: [
    o '',                                       -> new Expressions
    o 'Body'
    o 'Block TERMINATOR'
  ]

  # Any list of statements and expressions, separated by line breaks or semicolons.
  Body: [
    o 'Line',                                   -> Expressions.wrap [$1]
    o 'Body TERMINATOR Line',                   -> $1.push $3
    o 'Body TERMINATOR'
  ]

  # Expressions and statements, which make up a line in a body.
  Line: [
    o 'Expression'
    o 'Statement'
  ]

  # Pure statements which cannot be expressions.
  Statement: [
    o 'Return'
    o 'Throw'
    o 'Comment'
    o 'STATEMENT',                              -> new Literal $1
  ]

  # All the different types of expressions in our language. The basic unit of
  # CoffeeScript is the **Expression** -- everything that can be an expression
  # is one. Expressions serve as the building blocks of many other rules, making
  # them somewhat circular.
  Expression: [
    o 'Value'
    o 'Invocation'
    o 'Code'
    o 'Operation'
    o 'Assign'
    o 'If'
    o 'Try'
    o 'While'
    o 'For'
    o 'Switch'
    o 'Class'
  ]

  # An indented block of expressions. Note that the [Rewriter](rewriter.html)
  # will convert some postfix forms into blocks for us, by adjusting the
  # token stream.
  Block: [
    o 'INDENT Body OUTDENT',                    -> $2
    o 'INDENT OUTDENT',                         -> new Expressions
  ]

  # A literal identifier, a variable name or property.
  Identifier: [
    o 'IDENTIFIER',                             -> new Literal $1
  ]

  # Alphanumerics are separated from the other **Literal** matchers because
  # they can also serve as keys in object literals.
  AlphaNumeric: [
    o 'NUMBER',                                 -> new Literal $1
    o 'STRING',                                 -> new Literal $1
  ]

  # All of our immediate values. These can (in general), be passed straight
  # through and printed to JavaScript.
  Literal: [
    o 'AlphaNumeric'
    o 'JS',                                     -> new Literal $1
    o 'REGEX',                                  -> new Literal $1
    o 'BOOL',                                   ->
      new Literal if $1 is 'undefined' then 'void 0' else $1
  ]

  # Assignment of a variable, property, or index to a value.
  Assign: [
    o 'Assignable = Expression',                -> new Assign $1, $3
    o 'Assignable = INDENT Expression OUTDENT', -> new Assign $1, $4
  ]

  # Assignment when it happens within an object literal. The difference from
  # the ordinary **Assign** is that these allow numbers and strings as keys.
  AssignObj: [
    o 'ObjAssignable',                          -> new Value $1
    o 'ObjAssignable : Expression',             -> new Assign new Value($1), $3, 'object'
    o 'ObjAssignable :
       INDENT Expression OUTDENT',              -> new Assign new Value($1), $4, 'object'
    o 'Comment'
  ]

  ObjAssignable: [
    o 'Identifier'
    o 'AlphaNumeric'
    o 'ThisProperty'
  ]

  # A return statement from a function body.
  Return: [
    o 'RETURN Expression',                      -> new Return $2
    o 'RETURN',                                 -> new Return
  ]

  # A block comment.
  Comment: [
    o 'HERECOMMENT',                            -> new Comment $1
  ]

  # The **Code** node is the function literal. It's defined by an indented block
  # of **Expressions** preceded by a function arrow, with an optional parameter
  # list.
  Code: [
    o 'PARAM_START ParamList PARAM_END FuncGlyph Block', -> new Code $2, $5, $4
    o 'FuncGlyph Block',                        -> new Code [], $2, $1
  ]

  # CoffeeScript has two different symbols for functions. `->` is for ordinary
  # functions, and `=>` is for functions bound to the current value of *this*.
  FuncGlyph: [
    o '->',                                     -> 'func'
    o '=>',                                     -> 'boundfunc'
  ]

  # An optional, trailing comma.
  OptComma: [
    o ''
    o ','
  ]

  # The list of parameters that a function accepts can be of any length.
  ParamList: [
    o '',                                       -> []
    o 'Param',                                  -> [$1]
    o 'ParamList , Param',                      -> $1.concat $3
  ]

  # A single parameter in a function definition can be ordinary, or a splat
  # that hoovers up the remaining arguments.
  Param: [
    o 'ParamVar',                               -> new Param $1
    o 'ParamVar ...',                           -> new Param $1, null, on
    o 'ParamVar = Expression',                  -> new Param $1, $3
  ]

  ParamVar: [
    o 'Identifier'
    o 'ThisProperty'
    o 'Array'
    o 'Object'
  ]

  # A splat that occurs outside of a parameter list.
  Splat: [
    o 'Expression ...',                         -> new Splat $1
  ]

  # Variables and properties that can be assigned to.
  SimpleAssignable: [
    o 'Identifier',                             -> new Value $1
    o 'Value Accessor',                         -> $1.push $2
    o 'Invocation Accessor',                    -> new Value $1, [$2]
    o 'ThisProperty'
  ]

  # Everything that can be assigned to.
  Assignable: [
    o 'SimpleAssignable'
    o 'Array',                                  -> new Value $1
    o 'Object',                                 -> new Value $1
  ]

  # The types of things that can be treated as values -- assigned to, invoked
  # as functions, indexed into, named as a class, etc.
  Value: [
    o 'Assignable'
    o 'Literal',                                -> new Value $1
    o 'Parenthetical',                          -> new Value $1
    o 'Range',                                  -> new Value $1
    o 'This'
  ]

  # The general group of accessors into an object, by property, by prototype
  # or by array index or slice.
  Accessor: [
    o '.  Identifier',                          -> new Access $2
    o '?. Identifier',                          -> new Access $2, 'soak'
    o ':: Identifier',                          -> new Access $2, 'proto'
    o '::',                                     -> new Access new Literal 'prototype'
    o 'Index'
    o 'Slice',                                  -> new Slice $1
  ]

  # Indexing into an object or array using bracket notation.
  Index: [
    o 'INDEX_START Expression INDEX_END',       -> new Index $2
    o 'INDEX_SOAK  Index',                      -> extend $2, soak : yes
    o 'INDEX_PROTO Index',                      -> extend $2, proto: yes
  ]

  # In CoffeeScript, an object literal is simply a list of assignments.
  Object: [
    o '{ AssignList OptComma }',                -> new Obj $2, $1.generated
  ]

  # Assignment of properties within an object literal can be separated by
  # comma, as in JavaScript, or simply by newline.
  AssignList: [
    o '',                                                       -> []
    o 'AssignObj',                                              -> [$1]
    o 'AssignList , AssignObj',                                 -> $1.concat $3
    o 'AssignList OptComma TERMINATOR AssignObj',               -> $1.concat $4
    o 'AssignList OptComma INDENT AssignList OptComma OUTDENT', -> $1.concat $4
  ]

  # Class definitions have optional bodies of prototype property assignments,
  # and optional references to the superclass.
  Class: [
    o 'CLASS',                                      -> new Class
    o 'CLASS Block',                                -> new Class null, null, $2
    o 'CLASS EXTENDS Value',                        -> new Class null, $3
    o 'CLASS EXTENDS Value Block',                  -> new Class null, $3, $4
    o 'CLASS SimpleAssignable',                     -> new Class $2
    o 'CLASS SimpleAssignable Block',               -> new Class $2, null, $3
    o 'CLASS SimpleAssignable EXTENDS Value',       -> new Class $2, $4
    o 'CLASS SimpleAssignable EXTENDS Value Block', -> new Class $2, $4, $5
  ]

  # Ordinary function invocation, or a chained series of calls.
  Invocation: [
    o 'Value OptFuncExist Arguments',           -> new Call $1, $3, $2
    o 'Invocation OptFuncExist Arguments',      -> new Call $1, $3, $2
    o 'SUPER',                                  ->
      new Call 'super', [new Splat new Literal 'arguments']
    o 'SUPER Arguments',                        ->
      new Call 'super', $2
  ]

  # An optional existence check on a function.
  OptFuncExist: [
    o '',                                       -> no
    o 'FUNC_EXIST',                             -> yes
  ]

  # The list of arguments to a function call.
  Arguments: [
    o 'CALL_START CALL_END',                    -> []
    o 'CALL_START ArgList OptComma CALL_END',   -> $2
  ]

  # A reference to the *this* current object.
  This: [
    o 'THIS',                                   -> new Value new Literal 'this'
    o '@',                                      -> new Value new Literal 'this'
  ]

  # A reference to a property on *this*.
  ThisProperty: [
    o '@ Identifier',                           -> new Value new Literal('this'), [new Access($2)], 'this'
  ]

  # The array literal.
  Array: [
    o '[ ]',                                    -> new Arr []
    o '[ ArgList OptComma ]',                   -> new Arr $2
  ]

  # Inclusive and exclusive range dots.
  RangeDots: [
    o '..',                                     -> 'inclusive'
    o '...',                                    -> 'exclusive'
  ]

  # The CoffeeScript range literal.
  Range: [
    o '[ Expression RangeDots Expression ]',    -> new Range $2, $4, $3
  ]

  # Array slice literals.
  Slice: [
    o 'INDEX_START Expression RangeDots Expression INDEX_END', -> new Range $2, $4, $3
    o 'INDEX_START Expression RangeDots INDEX_END', -> new Range $2, null, $3
    o 'INDEX_START RangeDots Expression INDEX_END', -> new Range null, $3, $2
  ]

  # The **ArgList** is both the list of objects passed into a function call,
  # as well as the contents of an array literal
  # (i.e. comma-separated expressions). Newlines work as well.
  ArgList: [
    o 'Arg',                                              -> [$1]
    o 'ArgList , Arg',                                    -> $1.concat $3
    o 'ArgList OptComma TERMINATOR Arg',                  -> $1.concat $4
    o 'INDENT ArgList OptComma OUTDENT',                  -> $2
    o 'ArgList OptComma INDENT ArgList OptComma OUTDENT', -> $1.concat $4
  ]

  # Valid arguments are Expressions or Splats.
  Arg: [
    o 'Expression'
    o 'Splat'
  ]

  # Just simple, comma-separated, required arguments (no fancy syntax). We need
  # this to be separate from the **ArgList** for use in **Switch** blocks, where
  # having the newlines wouldn't make sense.
  SimpleArgs: [
    o 'Expression'
    o 'SimpleArgs , Expression',                -> [].concat $1, $3
  ]

  # The variants of *try/catch/finally* exception handling blocks.
  Try: [
    o 'TRY Block',                              -> new Try $2
    o 'TRY Block Catch',                        -> new Try $2, $3[0], $3[1]
    o 'TRY Block FINALLY Block',                -> new Try $2, null, null, $4
    o 'TRY Block Catch FINALLY Block',          -> new Try $2, $3[0], $3[1], $5
  ]

  # A catch clause names its error and runs a block of code.
  Catch: [
    o 'CATCH Identifier Block',                 -> [$2, $3]
  ]

  # Throw an exception object.
  Throw: [
    o 'THROW Expression',                       -> new Throw $2
  ]

  # Parenthetical expressions. Note that the **Parenthetical** is a **Value**,
  # not an **Expression**, so if you need to use an expression in a place
  # where only values are accepted, wrapping it in parentheses will always do
  # the trick.
  Parenthetical: [
    o '( Body )',                               -> new Parens $2
    o '( INDENT Body OUTDENT )',                -> new Parens $3
  ]

  # The condition portion of a while loop.
  WhileSource: [
    o 'WHILE Expression',                       -> new While $2
    o 'WHILE Expression WHEN Expression',       -> new While $2, guard: $4
    o 'UNTIL Expression',                       -> new While $2, invert: true
    o 'UNTIL Expression WHEN Expression',       -> new While $2, invert: true, guard: $4
  ]

  # The while loop can either be normal, with a block of expressions to execute,
  # or postfix, with a single expression. There is no do..while.
  While: [
    o 'WhileSource Block',                      -> $1.addBody $2
    o 'Statement  WhileSource',                 -> $2.addBody Expressions.wrap [$1]
    o 'Expression WhileSource',                 -> $2.addBody Expressions.wrap [$1]
    o 'Loop',                                   -> $1
  ]

  Loop: [
    o 'LOOP Block',                             -> new While(new Literal 'true').addBody $2
    o 'LOOP Expression',                        -> new While(new Literal 'true').addBody Expressions.wrap [$2]
  ]

  # Array, object, and range comprehensions, at the most generic level.
  # Comprehensions can either be normal, with a block of expressions to execute,
  # or postfix, with a single expression.
  For: [
    o 'Statement  ForBody',                     -> new For $1, $2, $2.vars[0], $2.vars[1]
    o 'Expression ForBody',                     -> new For $1, $2, $2.vars[0], $2.vars[1]
    o 'ForBody    Block',                       -> new For $2, $1, $1.vars[0], $1.vars[1]
  ]

  ForBody: [
    o 'FOR Range',                              -> source: new Value($2), vars: []
    o 'ForStart ForSource',                     -> $2.raw = $1.raw; $2.vars = $1; $2
  ]

  ForStart: [
    o 'FOR ForVariables',                       -> $2
    o 'FOR ALL ForVariables',                   -> $3.raw = yes; $3
  ]

  # An array of all accepted values for a variable inside the loop.
  # This enables support for pattern matching.
  ForValue: [
    o 'Identifier'
    o 'Array',                                  -> new Value $1
    o 'Object',                                 -> new Value $1
  ]

  # An array or range comprehension has variables for the current element
  # and (optional) reference to the current index. Or, *key, value*, in the case
  # of object comprehensions.
  ForVariables: [
    o 'ForValue',                               -> [$1]
    o 'ForValue , ForValue',                    -> [$1, $3]
  ]

  # The source of a comprehension is an array or object with an optional guard
  # clause. If it's an array comprehension, you can also choose to step through
  # in fixed-size increments.
  ForSource: [
    o 'FORIN Expression',                               -> source: $2
    o 'FOROF Expression',                               -> source: $2, object: yes
    o 'FORIN Expression WHEN Expression',               -> source: $2, guard: $4
    o 'FOROF Expression WHEN Expression',               -> source: $2, guard: $4, object: yes
    o 'FORIN Expression BY Expression',                 -> source: $2, step:  $4
    o 'FORIN Expression WHEN Expression BY Expression', -> source: $2, guard: $4, step: $6
    o 'FORIN Expression BY Expression WHEN Expression', -> source: $2, step:  $4, guard: $6
  ]

  Switch: [
    o 'SWITCH Expression INDENT Whens OUTDENT',            -> new Switch $2, $4
    o 'SWITCH Expression INDENT Whens ELSE Block OUTDENT', -> new Switch $2, $4, $6
    o 'SWITCH INDENT Whens OUTDENT',                       -> new Switch null, $3
    o 'SWITCH INDENT Whens ELSE Block OUTDENT',            -> new Switch null, $3, $5
  ]

  Whens: [
    o 'When'
    o 'Whens When',                             -> $1.concat $2
  ]

  # An individual **When** clause, with action.
  When: [
    o 'LEADING_WHEN SimpleArgs Block',            -> [[$2, $3]]
    o 'LEADING_WHEN SimpleArgs Block TERMINATOR', -> [[$2, $3]]
  ]

  # The most basic form of *if* is a condition and an action. The following
  # if-related rules are broken up along these lines in order to avoid
  # ambiguity.
  IfBlock: [
    o 'IF Expression Block',                    -> new If $2, $3
    o 'UNLESS Expression Block',                -> new If $2, $3, invert: true
    o 'IfBlock ELSE IF Expression Block',       -> $1.addElse new If $4, $5
    o 'IfBlock ELSE Block',                     -> $1.addElse $3
  ]

  # The full complement of *if* expressions, including postfix one-liner
  # *if* and *unless*.
  If: [
    o 'IfBlock'
    o 'Statement  POST_IF Expression',          -> new If $3, Expressions.wrap([$1]), statement: true
    o 'Expression POST_IF Expression',          -> new If $3, Expressions.wrap([$1]), statement: true
    o 'Statement  POST_UNLESS Expression',      -> new If $3, Expressions.wrap([$1]), statement: true, invert: true
    o 'Expression POST_UNLESS Expression',      -> new If $3, Expressions.wrap([$1]), statement: true, invert: true
  ]

  # Arithmetic and logical operators, working on one or more operands.
  # Here they are grouped by order of precedence. The actual precedence rules
  # are defined at the bottom of the page. It would be shorter if we could
  # combine most of these rules into a single generic *Operand OpSymbol Operand*
  # -type rule, but in order to make the precedence binding possible, separate
  # rules are necessary.
  Operation: [
    o 'UNARY Expression',                       -> new Op $1 , $2
    o '-     Expression',                      (-> new Op '-', $2), prec: 'UNARY'
    o '+     Expression',                      (-> new Op '+', $2), prec: 'UNARY'

    o '-- SimpleAssignable',                    -> new Op '--', $2
    o '++ SimpleAssignable',                    -> new Op '++', $2
    o 'SimpleAssignable --',                    -> new Op '--', $1, null, true
    o 'SimpleAssignable ++',                    -> new Op '++', $1, null, true

    # [The existential operator](http://jashkenas.github.com/coffee-script/#existence).
    o 'Expression ?',                           -> new Existence $1

    o 'Expression +  Expression',               -> new Op '+' , $1, $3
    o 'Expression -  Expression',               -> new Op '-' , $1, $3

    o 'Expression MATH     Expression',         -> new Op $2, $1, $3
    o 'Expression SHIFT    Expression',         -> new Op $2, $1, $3
    o 'Expression COMPARE  Expression',         -> new Op $2, $1, $3
    o 'Expression LOGIC    Expression',         -> new Op $2, $1, $3
    o 'Expression RELATION Expression',         ->
      if $2.charAt(0) is '!'
        new Op($2.slice(1), $1, $3).invert()
      else
        new Op $2, $1, $3

    o 'SimpleAssignable COMPOUND_ASSIGN
       Expression',                             -> new Assign $1, $3, $2
    o 'SimpleAssignable COMPOUND_ASSIGN
       INDENT Expression OUTDENT',              -> new Assign $1, $4, $2
    o 'SimpleAssignable EXTENDS Expression',    -> new Extends $1, $3
  ]


# Precedence
# ----------

# Operators at the top of this list have higher precedence than the ones lower
# down. Following these rules is what makes `2 + 3 * 4` parse as:
#
#     2 + (3 * 4)
#
# And not:
#
#     (2 + 3) * 4
operators = [
  ['left',      '.', '?.', '::']
  ['left',      'CALL_START', 'CALL_END']
  ['nonassoc',  '++', '--']
  ['left',      '?']
  ['right',     'UNARY']
  ['left',      'MATH']
  ['left',      '+', '-']
  ['left',      'SHIFT']
  ['left',      'RELATION']
  ['left',      'COMPARE']
  ['left',      'LOGIC']
  ['nonassoc',  'INDENT', 'OUTDENT']
  ['right',     '=', ':', 'COMPOUND_ASSIGN', 'RETURN', 'THROW', 'EXTENDS']
  ['right',     'FORIN', 'FOROF', 'BY', 'WHEN']
  ['right',     'IF', 'UNLESS', 'ELSE', 'FOR', 'WHILE', 'UNTIL', 'LOOP', 'SUPER', 'CLASS']
  ['right',     'POST_IF', 'POST_UNLESS']
]

# Wrapping Up
# -----------

# Finally, now what we have our **grammar** and our **operators**, we can create
# our **Jison.Parser**. We do this by processing all of our rules, recording all
# terminals (every symbol which does not appear as the name of a rule above)
# as "tokens".
tokens = []
for all name, alternatives of grammar
  grammar[name] = for alt in alternatives
    for token in alt[0].split ' '
      tokens.push token unless grammar[token]
    alt[1] = "return #{alt[1]}" if name is 'Root'
    alt

# Initialize the **Parser** with our list of terminal **tokens**, our **grammar**
# rules, and the name of the root. Reverse the operators because Jison orders
# precedence from low to high, and we have it high to low
# (as in [Yacc](http://dinosaur.compilertools.net/yacc/index.html)).
exports.parser = new Parser
  tokens      : tokens.join ' '
  bnf         : grammar
  operators   : operators.reverse()
  startSymbol : 'Root'
