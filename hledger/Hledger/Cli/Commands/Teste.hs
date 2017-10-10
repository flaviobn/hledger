{-|

Teste

-}

module Hledger.Cli.Commands.Teste
where

import System.Console.CmdArgs.Explicit

import Hledger
import Hledger.Cli.CliOptions
import Prelude


testemode :: Mode RawOpts
testemode = (defCommandMode $ ["teste"] ++ aliases) {
  modeHelp = "teste testando" `withAliases` aliases
  ,modeHelpSuffix = []
  ,modeGroupFlags = Group {
      groupUnnamed = []
      ,groupHidden = []
      ,groupNamed = [generalflagsgroup1]
      }
  ,modeArgs = ([], Just $ argsFlag "[Date] Description [Amount]")
  }
  where aliases = []

teste :: CliOpts -> Journal -> IO ()
teste CliOpts{rawopts_=rawopts} _ = do
  d <- getCurrentDay
  let args = listofstringopt "args" rawopts
  mapM_ putStrLn args
  putStrLn $ show d

  

  
