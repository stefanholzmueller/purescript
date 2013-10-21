-----------------------------------------------------------------------------
--
-- Module      :  PureScript.Parser.Common
-- Copyright   :  (c) Phil Freeman 2013
-- License     :  MIT
--
-- Maintainer  :  Phil Freeman <paf31@cantab.net>
-- Stability   :  experimental
-- Portability :
--
-- |
--
-----------------------------------------------------------------------------

{-# LANGUAGE FlexibleContexts #-}

module PureScript.Parser.Common where

import Data.Char (isSpace)
import Control.Applicative
import Control.Monad
import Control.Monad.State
import qualified Text.Parsec as P
import qualified Text.Parsec.Pos as P
import qualified Text.Parsec.Token as PT

import PureScript.Names

reservedNames :: [String]
reservedNames = [ "case"
                , "data"
                , "type"
                , "var"
                , "val"
                , "while"
                , "for"
                , "foreach"
                , "if"
                , "then"
                , "else"
                , "return"
                , "true"
                , "false"
                , "extern"
                , "forall"
                , "do"
                , "until"
                , "in" ]

reservedOpNames :: [String]
reservedOpNames = [ "!", "~", "-", "<=", ">=", "<", ">", "*", "/", "%", "++", "+", "<<", ">>>", ">>"
                  , "==", "!=", "&", "^", "|", "&&", "||" ]

identStart :: P.Parsec String u Char
identStart = P.lower <|> P.oneOf "_$"

properNameStart :: P.Parsec String u Char
properNameStart = P.upper

identLetter :: P.Parsec String u Char
identLetter = P.alphaNum <|> P.oneOf "_'"

opStart :: P.Parsec String u Char
opStart = P.oneOf "!#$%&*+/<=>?@^|-~"

opLetter :: P.Parsec String u Char
opLetter = P.oneOf ":#$%&*+./<=>?@^|"

langDef = PT.LanguageDef
  { PT.reservedNames   = reservedNames
  , PT.reservedOpNames = reservedOpNames
  , PT.commentStart    = "{-"
  , PT.commentEnd      = "-}"
  , PT.commentLine     = "--"
  , PT.nestedComments  = True
  , PT.identStart      = identStart
  , PT.identLetter     = identLetter
  , PT.opStart         = opStart
  , PT.opLetter        = opLetter
  , PT.caseSensitive   = True
  }

tokenParser = PT.makeTokenParser langDef

lexeme           = PT.lexeme            tokenParser
identifier       = PT.identifier        tokenParser
reserved         = PT.reserved          tokenParser
reservedOp       = PT.reservedOp        tokenParser
operator         = PT.operator          tokenParser
stringLiteral    = PT.stringLiteral     tokenParser
whiteSpace       = PT.whiteSpace        tokenParser
parens           = PT.parens            tokenParser
braces           = PT.braces            tokenParser
angles           = PT.angles            tokenParser
squares          = PT.squares           tokenParser
semi             = PT.semi              tokenParser
comma            = PT.comma             tokenParser
colon            = PT.colon             tokenParser
dot              = PT.dot               tokenParser
semiSep          = PT.semiSep           tokenParser
semiSep1         = PT.semiSep1          tokenParser
commaSep         = PT.commaSep          tokenParser
commaSep1        = PT.commaSep1         tokenParser

tick :: P.Parsec String u Char
tick = lexeme $ P.char '`'

properName :: P.Parsec String u String
properName = lexeme $ P.try ((:) <$> P.upper <*> many (PT.identLetter langDef) P.<?> "name")

integerOrFloat :: P.Parsec String u (Either Integer Double)
integerOrFloat = Left <$> P.try (PT.integer tokenParser) <|>
                 Right <$> P.try (PT.float tokenParser)

augment :: P.Stream s m t => P.ParsecT s u m a -> P.ParsecT s u m b -> (a -> b -> a) -> P.ParsecT s u m a
augment p q f = (flip $ maybe id $ flip f) <$> p <*> P.optionMaybe q

fold :: P.Stream s m t => P.ParsecT s u m a -> P.ParsecT s u m b -> (a -> b -> a) -> P.ParsecT s u m a
fold first more combine = do
  a <- first
  bs <- P.many more
  return $ foldl combine a bs

parseIdent :: P.Parsec String u Ident
parseIdent = (Ident <$> identifier) <|> (Op <$> parens operator)

parseIdentInfix :: P.Parsec String u Ident
parseIdentInfix = (Ident <$> P.between tick tick identifier) <|> (Op <$> operator)

mark :: P.Parsec String P.Column a -> P.Parsec String P.Column a
mark p = do
  current <- P.getState
  pos <- P.sourceColumn <$> P.getPosition
  P.putState pos
  a <- p
  P.putState current
  return a

checkIndentation :: (P.Column -> P.Column -> Bool) -> P.Parsec String P.Column ()
checkIndentation rel = (do
  col <- P.sourceColumn <$> P.getPosition
  current <- P.getState
  guard $ col `rel` current) <|> P.parserFail "Indentation check"

indented :: P.Parsec String P.Column ()
indented = checkIndentation (>)

same :: P.Parsec String P.Column ()
same = checkIndentation (==)

runIndentParser :: P.Column -> P.Parsec String P.Column a -> String -> Either P.ParseError a
runIndentParser col p = P.runParser p 0 ""
