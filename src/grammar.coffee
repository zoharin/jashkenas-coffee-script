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
Parser: require('jison').Parser

# Jison DSL
# ---------

# Since we're going to be wrapped in a function by Jison in any case, if our
# action immediately returns a value, we can optimize by removing the function
# wrapper and just returning the value directly.
unwrap: /function\s*\(\)\s*\{\s*return\s*([\s\S]*);\s*\}/

# Our handy DSL for Jison grammar generation, thanks to
# [Tim Caswell](http://github.com/creationix). For every rule in the grammar,
# we pass the pattern-defining string, the action to run, and extra options,
# optionally. If no action is specified, we simply pass the value of the
# previous nonterminal.
o: (pattern_string, action, options) ->
  return [pattern_string, '$$ = $1;', options] unless action
  action: if match: (action + '').match(unwrap) then match[1] else "($action())"
  [pattern_string, "$$ = $action;", options]

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
grammar: {

  # The **Root** is the top-level node in the syntax tree. Since we parse bottom-up,
  # all parsing must end here.
  Root: [
    o "",                                       -> new Expressions()
    o "TERMINATOR",                             -> new Expressions()
    o "Body"
    o "Block TERMINATOR"
  ]

  # Any list of statements and expressions, seperated by line breaks or semicolons.
  Body: [
    o "Line",                                   -> Expressions.wrap [$1]
    o "Body TERMINATOR Line",                   -> $1.push $3
    o "Body TERMINATOR"
  ]

  # Expressions and statements, which make up a line in a body.
  Line: [
    o "Expression"
    o "Statement"
  ]

  # Pure statements which cannot be expressions.
  Statement: [
    o "Return"
    o "Throw"
    o "BREAK",                                  -> new LiteralNode $1
    o "CONTINUE",                               -> new LiteralNode $1
  ]

  # All the different types of expressions in our language. The basic unit of
  # CoffeeScript is the **Expression** -- everything that can be an expression
  # is one. Expressions serve as the building blocks of many other rules, making
  # them somewhat circular.
  Expression: [
    o "Value"
    o "Call"
    o "Curry"
    o "Code"
    o "Operation"
    o "Assign"
    o "If"
    o "Try"
    o "While"
    o "For"
    o "Switch"
    o "Extends"
    o "Class"
    o "Splat"
    o "Existence"
    o "Comment"
    o "Extension"
  ]

  # A an indented block of expressions. Note that the [Rewriter](rewriter.html)
  # will convert some postfix forms into blocks for us, by adjusting the
  # token stream.
  Block: [
    o "INDENT Body OUTDENT",                    -> $2
    o "INDENT OUTDENT",                         -> new Expressions()
    o "TERMINATOR Comment",                     -> Expressions.wrap [$2]
  ]

  # A literal identifier, a variable name or property.
  Identifier: [
    o "IDENTIFIER",                             -> new LiteralNode $1
  ]

  # Alphanumerics are separated from the other **Literal** matchers because
  # they can also serve as keys in object literals.
  AlphaNumeric: [
    o "NUMBER",                                 -> new LiteralNode $1
    o "STRING",                                 -> new LiteralNode $1
  ]

  # All of our immediate values. These can (in general), be passed straight
  # through and printed to JavaScript.
  Literal: [
    o "AlphaNumeric"
    o "JS",                                     -> new LiteralNode $1
    o "REGEX",                                  -> new LiteralNode $1
    o "TRUE",                                   -> new LiteralNode true
    o "FALSE",                                  -> new LiteralNode false
    o "YES",                                    -> new LiteralNode true
    o "NO",                                     -> new LiteralNode false
    o "ON",                                     -> new LiteralNode true
    o "OFF",                                    -> new LiteralNode false
  ]

  # Assignment of a variable, property, or index to a value.
  Assign: [
    o "Assignable ASSIGN Expression",           -> new AssignNode $1, $3
  ]

  # Assignment when it happens within an object literal. The difference from
  # the ordinary **Assign** is that these allow numbers and strings as keys.
  AssignObj: [
    o "Identifier",                             -> new ValueNode $1
    o "AlphaNumeric"
    o "Identifier ASSIGN Expression",           -> new AssignNode new ValueNode($1), $3, 'object'
    o "AlphaNumeric ASSIGN Expression",         -> new AssignNode new ValueNode($1), $3, 'object'
    o "Comment"
  ]

  # A return statement from a function body.
  Return: [
    o "RETURN Expression",                      -> new ReturnNode $2
    o "RETURN",                                 -> new ReturnNode new ValueNode new LiteralNode 'null'
  ]

  # A comment. Because CoffeeScript passes comments through to JavaScript, we
  # have to parse comments like any other construct, and identify all of the
  # positions in which they can occur in the grammar.
  Comment: [
    o "COMMENT",                                -> new CommentNode $1
  ]

  # [The existential operator](http://jashkenas.github.com/coffee-script/#existence).
  Existence: [
    o "Expression ?",                           -> new ExistenceNode $1
  ]

  # The **Code** node is the function literal. It's defined by an indented block
  # of **Expressions** preceded by a function arrow, with an optional parameter
  # list.
  Code: [
    o "PARAM_START ParamList PARAM_END FuncGlyph Block", -> new CodeNode $2, $5, $4
    o "FuncGlyph Block",                        -> new CodeNode [], $2, $1
  ]

  # CoffeeScript has two different symbols for functions. `->` is for ordinary
  # functions, and `=>` is for functions bound to the current value of *this*.
  FuncGlyph: [
    o "->",                                     -> 'func'
    o "=>",                                     -> 'boundfunc'
  ]

  # An optional, trailing comma.
  OptComma: [
    o ''
    o ','
  ]

  # The list of parameters that a function accepts can be of any length.
  ParamList: [
    o "",                                       -> []
    o "Param",                                  -> [$1]
    o "ParamList , Param",                      -> $1.concat [$3]
  ]

  # A single parameter in a function definition can be ordinary, or a splat
  # that hoovers up the remaining arguments.
  Param: [
    o "PARAM",                                  -> new LiteralNode $1
    o "Param . . .",                            -> new SplatNode $1
  ]

  # A splat that occurs outside of a parameter list.
  Splat: [
    o "Expression . . .",                       -> new SplatNode $1
  ]

  # Variables and properties that can be assigned to.
  SimpleAssignable: [
    o "Identifier",                             -> new ValueNode $1
    o "Value Accessor",                         -> $1.push $2
    o "Invocation Accessor",                    -> new ValueNode $1, [$2]
    o "ThisProperty"
  ]

  # Everything that can be assigned to.
  Assignable: [
    o "SimpleAssignable"
    o "Array",                                  -> new ValueNode $1
    o "Object",                                 -> new ValueNode $1
  ]

  # The types of things that can be treated as values -- assigned to, invoked
  # as functions, indexed into, named as a class, etc.
  Value: [
    o "Assignable"
    o "Literal",                                -> new ValueNode $1
    o "Parenthetical",                          -> new ValueNode $1
    o "Range",                                  -> new ValueNode $1
    o "This"
    o "NULL",                                   -> new ValueNode new LiteralNode 'null'
  ]

  # The general group of accessors into an object, by property, by prototype
  # or by array index or slice.
  Accessor: [
    o "PROPERTY_ACCESS Identifier",             -> new AccessorNode $2
    o "PROTOTYPE_ACCESS Identifier",            -> new AccessorNode $2, 'prototype'
    o "::",                                     -> new AccessorNode(new LiteralNode('prototype'))
    o "SOAK_ACCESS Identifier",                 -> new AccessorNode $2, 'soak'
    o "Index"
    o "Slice",                                  -> new SliceNode $1
  ]

  # Indexing into an object or array using bracket notation.
  Index: [
    o "INDEX_START Expression INDEX_END",       -> new IndexNode $2
    o "SOAKED_INDEX_START Expression SOAKED_INDEX_END", -> new IndexNode $2, 'soak'
  ]

  # In CoffeeScript, an object literal is simply a list of assignments.
  Object: [
    o "{ AssignList OptComma }",                -> new ObjectNode $2
  ]

  # Assignment of properties within an object literal can be separated by
  # comma, as in JavaScript, or simply by newline.
  AssignList: [
    o "",                                       -> []
    o "AssignObj",                              -> [$1]
    o "AssignList , AssignObj",                 -> $1.concat [$3]
    o "AssignList TERMINATOR AssignObj",        -> $1.concat [$3]
    o "AssignList , TERMINATOR AssignObj",      -> $1.concat [$4]
    o "INDENT AssignList OptComma OUTDENT",     -> $2
  ]

  # Class definitions have optional bodies of prototype property assignments,
  # and optional references to the superclass.
  Class: [
    o "CLASS SimpleAssignable",                 -> new ClassNode $2
    o "CLASS SimpleAssignable EXTENDS Value",   -> new ClassNode $2, $4
    o "CLASS SimpleAssignable INDENT ClassBody OUTDENT", -> new ClassNode $2, null, $4
    o "CLASS SimpleAssignable EXTENDS Value INDENT ClassBody OUTDENT", -> new ClassNode $2, $4, $6
  ]

  # Assignments that can happen directly inside a class declaration.
  ClassAssign: [
    o "AssignObj",                              -> $1
    o "ThisProperty ASSIGN Expression",         -> new AssignNode new ValueNode($1), $3, 'this'
  ]

  # A list of assignments to a class.
  ClassBody: [
    o "",                                       -> []
    o "ClassAssign",                            -> [$1]
    o "ClassBody TERMINATOR ClassAssign",       -> $1.concat $3
  ]

  # The three flavors of function call: normal, object instantiation with `new`,
  # and calling `super()`
  Call: [
    o "Invocation"
    o "NEW Invocation",                         -> $2.new_instance()
    o "Super"
  ]

  # Binds a function call to a context and/or arguments.
  Curry: [
    o "Value <- Arguments",                     -> new CurryNode $1, $3
  ]

  # Extending an object by setting its prototype chain to reference a parent
  # object.
  Extends: [
    o "SimpleAssignable EXTENDS Value",         -> new ExtendsNode $1, $3
  ]

  # Ordinary function invocation, or a chained series of calls.
  Invocation: [
    o "Value Arguments",                        -> new CallNode $1, $2
    o "Invocation Arguments",                   -> new CallNode $1, $2
  ]

  # The list of arguments to a function call.
  Arguments: [
    o "CALL_START ArgList OptComma CALL_END",   -> $2
  ]

  # Calling super.
  Super: [
    o "SUPER CALL_START ArgList OptComma CALL_END", -> new CallNode 'super', $3
  ]

  # A reference to the *this* current object.
  This: [
    o "THIS",                                   -> new ValueNode new LiteralNode 'this'
    o "@",                                      -> new ValueNode new LiteralNode 'this'
  ]

  # A reference to a property on *this*.
  ThisProperty: [
    o "@ Identifier",                           -> new ValueNode new LiteralNode('this'), [new AccessorNode($2)]
  ]

  # The CoffeeScript range literal.
  Range: [
    o "[ Expression . . Expression ]",          -> new RangeNode $2, $5
    o "[ Expression . . . Expression ]",        -> new RangeNode $2, $6, true
  ]

  # The slice literal.
  Slice: [
    o "INDEX_START Expression . . Expression INDEX_END", -> new RangeNode $2, $5
    o "INDEX_START Expression . . . Expression INDEX_END", -> new RangeNode $2, $6, true
  ]

  # The array literal.
  Array: [
    o "[ ArgList OptComma ]",                   -> new ArrayNode $2
  ]

  # The **ArgList** is both the list of objects passed into a function call,
  # as well as the contents of an array literal
  # (i.e. comma-separated expressions). Newlines work as well.
  ArgList: [
    o "",                                       -> []
    o "Expression",                             -> [$1]
    o "INDENT Expression",                      -> [$2]
    o "ArgList , Expression",                   -> $1.concat [$3]
    o "ArgList TERMINATOR Expression",          -> $1.concat [$3]
    o "ArgList , TERMINATOR Expression",        -> $1.concat [$4]
    o "ArgList , INDENT Expression",            -> $1.concat [$4]
    o "ArgList OptComma OUTDENT"
  ]

  # Just simple, comma-separated, required arguments (no fancy syntax). We need
  # this to be separate from the **ArgList** for use in **Switch** blocks, where
  # having the newlines wouldn't make sense.
  SimpleArgs: [
    o "Expression"
    o "SimpleArgs , Expression",                ->
      if $1 instanceof Array then $1.concat([$3]) else [$1].concat([$3])
  ]

  # The variants of *try/catch/finally* exception handling blocks.
  Try: [
    o "TRY Block Catch",                        -> new TryNode $2, $3[0], $3[1]
    o "TRY Block FINALLY Block",                -> new TryNode $2, null, null, $4
    o "TRY Block Catch FINALLY Block",          -> new TryNode $2, $3[0], $3[1], $5
  ]

  # A catch clause names its error and runs a block of code.
  Catch: [
    o "CATCH Identifier Block",                 -> [$2, $3]
  ]

  # Throw an exception object.
  Throw: [
    o "THROW Expression",                       -> new ThrowNode $2
  ]

  # Parenthetical expressions. Note that the **Parenthetical** is a **Value**,
  # not an **Expression**, so if you need to use an expression in a place
  # where only values are accepted, wrapping it in parentheses will always do
  # the trick.
  Parenthetical: [
    o "( Line )",                               -> new ParentheticalNode $2
  ]

  # A language extension to CoffeeScript from the outside. We simply pass
  # it through unaltered.
  Extension: [
    o "EXTENSION"
  ]

  # The condition portion of a while loop.
  WhileSource: [
    o "WHILE Expression",                       -> new WhileNode $2
    o "WHILE Expression WHEN Expression",       -> new WhileNode $2, {guard : $4}
    o "UNTIL Expression",                       -> new WhileNode $2, {invert: true}
    o "UNTIL Expression WHEN Expression",       -> new WhileNode $2, {invert: true, guard: $4}
  ]

  # The while loop can either be normal, with a block of expressions to execute,
  # or postfix, with a single expression. There is no do..while.
  While: [
    o "WhileSource Block",                      -> $1.add_body $2
    o "Statement WhileSource",                  -> $2.add_body Expressions.wrap [$1]
    o "Expression WhileSource",                 -> $2.add_body Expressions.wrap [$1]
  ]

  # Array, object, and range comprehensions, at the most generic level.
  # Comprehensions can either be normal, with a block of expressions to execute,
  # or postfix, with a single expression.
  For: [
    o "Statement FOR ForVariables ForSource",   -> new ForNode $1, $4, $3[0], $3[1]
    o "Expression FOR ForVariables ForSource",  -> new ForNode $1, $4, $3[0], $3[1]
    o "FOR ForVariables ForSource Block",       -> new ForNode $4, $3, $2[0], $2[1]
  ]

  # An array of all accepted values for a variable inside the loop. This
  # enables support for pattern matching.
  ForValue: [
    o "Identifier"
    o "Array",                                  -> new ValueNode $1
    o "Object",                                 -> new ValueNode $1
  ]

  # An array or range comprehension has variables for the current element and
  # (optional) reference to the current index. Or, *key, value*, in the case
  # of object comprehensions.
  ForVariables: [
    o "ForValue",                               -> [$1]
    o "ForValue , ForValue",                    -> [$1, $3]
  ]

  # The source of a comprehension is an array or object with an optional guard
  # clause. If it's an array comprehension, you can also choose to step through
  # in fixed-size increments.
  ForSource: [
    o "IN Expression",                               -> {source: $2}
    o "OF Expression",                               -> {source: $2, object: true}
    o "IN Expression WHEN Expression",               -> {source: $2, guard: $4}
    o "OF Expression WHEN Expression",               -> {source: $2, guard: $4, object: true}
    o "IN Expression BY Expression",                 -> {source: $2, step:   $4}
    o "IN Expression WHEN Expression BY Expression", -> {source: $2, guard: $4, step:   $6}
    o "IN Expression BY Expression WHEN Expression", -> {source: $2, step:   $4, guard: $6}
  ]

  # The CoffeeScript switch/when/else block replaces the JavaScript
  # switch/case/default by compiling into an if-else chain.
  Switch: [
    o "SWITCH Expression INDENT Whens OUTDENT", -> $4.switches_over $2
    o "SWITCH Expression INDENT Whens ELSE Block OUTDENT", -> $4.switches_over($2).add_else $6, true
  ]

  # The inner list of whens is left recursive. At code-generation time, the
  # IfNode will rewrite them into a proper chain.
  Whens: [
    o "When"
    o "Whens When",                             -> $1.add_else $2
  ]

  # An individual **When** clause, with action.
  When: [
    o "LEADING_WHEN SimpleArgs Block",            -> new IfNode $2, $3, {statement: true}
    o "LEADING_WHEN SimpleArgs Block TERMINATOR", -> new IfNode $2, $3, {statement: true}
    o "Comment TERMINATOR When",                  -> $3.comment: $1; $3
  ]

  # The most basic form of *if* is a condition and an action. The following
  # if-related rules are broken up along these lines in order to avoid
  # ambiguity.
  IfStart: [
    o "IF Expression Block",                    -> new IfNode $2, $3
    o "UNLESS Expression Block",                -> new IfNode $2, $3, {invert: true}
    o "IfStart ElsIf",                          -> $1.add_else $2
  ]

  # An **IfStart** can optionally be followed by an else block.
  IfBlock: [
    o "IfStart"
    o "IfStart ELSE Block",                     -> $1.add_else $3
  ]

  # An *else if* continuation of the *if* expression.
  ElsIf: [
    o "ELSE IF Expression Block",               -> (new IfNode($3, $4)).force_statement()
  ]

  # The full complement of *if* expressions, including postfix one-liner
  # *if* and *unless*.
  If: [
    o "IfBlock"
    o "Statement IF Expression",                -> new IfNode $3, Expressions.wrap([$1]), {statement: true}
    o "Expression IF Expression",               -> new IfNode $3, Expressions.wrap([$1]), {statement: true}
    o "Statement UNLESS Expression",            -> new IfNode $3, Expressions.wrap([$1]), {statement: true, invert: true}
    o "Expression UNLESS Expression",           -> new IfNode $3, Expressions.wrap([$1]), {statement: true, invert: true}
  ]

  # Arithmetic and logical operators, working on one or more operands.
  # Here they are grouped by order of precedence. The actual precedence rules
  # are defined at the bottom of the page. It would be shorter if we could
  # combine most of these rules into a single generic *Operand OpSymbol Operand*
  # -type rule, but in order to make the precedence binding possible, separate
  # rules are necessary.
  Operation: [
    o "! Expression",                           -> new OpNode '!', $2
    o "!! Expression",                          -> new OpNode '!!', $2
    o("- Expression",                           (-> new OpNode('-', $2)), {prec: 'UMINUS'})
    o("+ Expression",                           (-> new OpNode('+', $2)), {prec: 'UPLUS'})
    o "~ Expression",                           -> new OpNode '~', $2
    o "-- Expression",                          -> new OpNode '--', $2
    o "++ Expression",                          -> new OpNode '++', $2
    o "DELETE Expression",                      -> new OpNode 'delete', $2
    o "TYPEOF Expression",                      -> new OpNode 'typeof', $2
    o "Expression --",                          -> new OpNode '--', $1, null, true
    o "Expression ++",                          -> new OpNode '++', $1, null, true

    o "Expression * Expression",                -> new OpNode '*', $1, $3
    o "Expression / Expression",                -> new OpNode '/', $1, $3
    o "Expression % Expression",                -> new OpNode '%', $1, $3

    o "Expression + Expression",                -> new OpNode '+', $1, $3
    o "Expression - Expression",                -> new OpNode '-', $1, $3

    o "Expression << Expression",               -> new OpNode '<<', $1, $3
    o "Expression >> Expression",               -> new OpNode '>>', $1, $3
    o "Expression >>> Expression",              -> new OpNode '>>>', $1, $3
    o "Expression & Expression",                -> new OpNode '&', $1, $3
    o "Expression | Expression",                -> new OpNode '|', $1, $3
    o "Expression ^ Expression",                -> new OpNode '^', $1, $3

    o "Expression <= Expression",               -> new OpNode '<=', $1, $3
    o "Expression < Expression",                -> new OpNode '<', $1, $3
    o "Expression > Expression",                -> new OpNode '>', $1, $3
    o "Expression >= Expression",               -> new OpNode '>=', $1, $3

    o "Expression == Expression",               -> new OpNode '==', $1, $3
    o "Expression != Expression",               -> new OpNode '!=', $1, $3

    o "Expression && Expression",               -> new OpNode '&&', $1, $3
    o "Expression || Expression",               -> new OpNode '||', $1, $3
    o "Expression ? Expression",                -> new OpNode '?', $1, $3

    o "Expression -= Expression",               -> new OpNode '-=', $1, $3
    o "Expression += Expression",               -> new OpNode '+=', $1, $3
    o "Expression /= Expression",               -> new OpNode '/=', $1, $3
    o "Expression *= Expression",               -> new OpNode '*=', $1, $3
    o "Expression %= Expression",               -> new OpNode '%=', $1, $3
    o "Expression ||= Expression",              -> new OpNode '||=', $1, $3
    o "Expression &&= Expression",              -> new OpNode '&&=', $1, $3
    o "Expression ?= Expression",               -> new OpNode '?=', $1, $3

    o "Expression INSTANCEOF Expression",       -> new OpNode 'instanceof', $1, $3
    o "Expression IN Expression",               -> new OpNode 'in', $1, $3
  ]

}

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
operators: [
  ["left",      '?']
  ["nonassoc",  'UMINUS', 'UPLUS', '!', '!!', '~', '++', '--']
  ["left",      '*', '/', '%']
  ["left",      '+', '-']
  ["left",      '<<', '>>', '>>>']
  ["left",      '&', '|', '^']
  ["left",      '<=', '<', '>', '>=']
  ["right",     'DELETE', 'INSTANCEOF', 'TYPEOF']
  ["left",      '==', '!=']
  ["left",      '&&', '||']
  ["right",     '-=', '+=', '/=', '*=', '%=', '||=', '&&=', '?=']
  ["left",      '.']
  ["right",     'INDENT']
  ["left",      'OUTDENT']
  ["right",     'WHEN', 'LEADING_WHEN', 'IN', 'OF', 'BY', 'THROW']
  ["right",     'FOR', 'WHILE', 'UNTIL', 'NEW', 'SUPER', 'CLASS']
  ["left",      'EXTENDS']
  ["right",     'ASSIGN', 'RETURN']
  ["right",     '->', '=>', '<-', 'UNLESS', 'IF', 'ELSE']
]

# Wrapping Up
# -----------

# Finally, now what we have our **grammar** and our **operators**, we can create
# our **Jison.Parser**. We do this by processing all of our rules, recording all
# terminals (every symbol which does not appear as the name of a rule above)
# as "tokens".
tokens: []
for name, alternatives of grammar
  grammar[name]: for alt in alternatives
    for token in alt[0].split ' '
      tokens.push token unless grammar[token]
    alt[1] = "return ${alt[1]}" if name is 'Root'
    alt

# Initialize the **Parser** with our list of terminal **tokens**, our **grammar**
# rules, and the name of the root. Reverse the operators because Jison orders
# precedence from low to high, and we have it high to low
# (as in [Yacc](http://dinosaur.compilertools.net/yacc/index.html)).
exports.parser: new Parser {
  tokens:       tokens.join ' '
  bnf:          grammar
  operators:    operators.reverse()
  startSymbol:  'Root'
}
