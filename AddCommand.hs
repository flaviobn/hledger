{-| 

A simple add command to help with data entry.

-}

module AddCommand
where
import Ledger
import Options
import RegisterCommand (showRegisterReport)
import System.IO
import System.IO.Error
import Text.ParserCombinators.Parsec
import Utils (ledgerFromStringWithOpts)


-- | Read ledger transactions from the command line, prompting for each
-- field, and append them to the ledger file. If the ledger came from
-- stdin, this command has no effect.
add :: [Opt] -> [String] -> Ledger -> IO ()
add opts args l
    | filepath (rawledger l) == "-" = return ()
    | otherwise = do
  hPutStrLn stderr ("Please enter one or more transactions, which will be added to your ledger file.\n\
                    \A blank account or amount ends a transaction, control-d to finish.")
  ts <- getAndAddTransactions l
  hPutStrLn stderr $ printf "\nAdded %d transactions to %s ." (length ts) (filepath $ rawledger l)

-- | Read a number of ledger transactions from the command line,
-- prompting, validating, displaying and appending them to the ledger
-- file, until EOF.
getAndAddTransactions :: Ledger -> IO [LedgerTransaction]
getAndAddTransactions l = (do
  t <- getTransaction l >>= addTransaction l
  liftM (t:) (getAndAddTransactions l)
 ) `catch` (\e -> if isEOFError e then return [] else ioError e)

-- | Read a transaction from the command line.
getTransaction :: Ledger -> IO LedgerTransaction
getTransaction l = do
  today <- getCurrentDay
  datestr <- askFor "date" (Just $ showDate today)
            (Just $ \s -> null s || 
             (isRight $ parse (smartdate >> many spacenonewline >> eof) "" $ lowercase s))
  let date = fixSmartDate today $ fromparse $ (parse smartdate "" . lowercase) datestr
  description <- askFor "description" Nothing (Just $ not . null)
  let getpostingsandvalidate = do
                     ps <- getPostings []
                     let t = nullledgertxn{ltdate=date
                                          ,ltstatus=False
                                          ,ltdescription=description
                                          ,ltpostings=ps
                                          }
                     either (const retry) (return) $ balanceLedgerTransaction t
      retry = do
        hPutStrLn stderr $ nonzerobalanceerror ++ ". Re-enter:"
        getpostingsandvalidate
  getpostingsandvalidate

-- | Read two or more postings from the command line.
getPostings :: [Posting] -> IO [Posting]
getPostings prevps = do
  account <- askFor (printf "account %d" n) Nothing (Just $ \s -> not $ null s && (length prevps < 2))
  if null account
    then return prevps
    else do
      amount <- liftM (fromparse . parse (someamount <|> return missingamt) "")
               $ askFor (printf "amount  %d" n) Nothing
                     (Just $ \s -> (null s && (not $ null prevps)) ||
                                  (isRight $ parse (someamount>>many spacenonewline>>eof) "" s))
      let p = nullrawposting{paccount=account,pamount=amount}
      if amount == missingamt
        then return $ prevps ++ [p]
        else getPostings $ prevps ++ [p]
    where n = length prevps + 1

-- | Prompt and read a string value, possibly with a default and a validator.
-- A validator will cause the prompt to repeat until the input is valid.
askFor :: String -> Maybe String -> Maybe (String -> Bool) -> IO String
askFor prompt def validator = do
  hPutStr stderr $ prompt ++ (maybe "" showdef def) ++ ": "
  hFlush stderr
  l <- getLine
  let input = if null l then fromMaybe l def else l
  case validator of
    Just valid -> if valid input then return input else askFor prompt def validator
    Nothing -> return input
    where showdef s = " [" ++ s ++ "]"

-- | Append this transaction to the ledger's file.
addTransaction :: Ledger -> LedgerTransaction -> IO LedgerTransaction
addTransaction l t = do
  putStrLn =<< registerFromString (show t)
  appendToLedgerFile l $ show t
  return t

-- | Append data to the ledger's file, ensuring proper separation from any
-- existing data; or if the file is "-", dump it to stdout.
appendToLedgerFile :: Ledger -> String -> IO ()
appendToLedgerFile l s = 
    if f == "-"
    then putStr $ sep ++ s
    else appendFile f $ sep++s
    where 
      f = filepath $ rawledger l
      t = rawledgertext l
      sep | null $ strip t = ""
          | otherwise = replicate (2 - min 2 (length lastnls)) '\n'
          where lastnls = takeWhile (=='\n') $ reverse t

-- | Convert a string of ledger data into a register report.
registerFromString :: String -> IO String
registerFromString s = do
  now <- getCurrentLocalTime
  l <- ledgerFromStringWithOpts [] [] now s
  return $ showRegisterReport [] [] l

{- doctests

@
$ echo "2009/13/1"|hledger -f /dev/null add 2>&1|tail -1|sed -e's/\[[^]]*\]//g' # a bad date is not accepted
date : date : 
@

@
$ echo|hledger -f /dev/null add 2>&1|tail -1|sed -e's/\[[^]]*\]//g' # a blank date is ok
date : description: 
@

@
$ printf "\n\n"|hledger -f /dev/null add 2>&1|tail -1|sed -e's/\[[^]]*\]//g' # a blank description should fail
date : description: description: 
@

-}
