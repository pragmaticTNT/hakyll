-- | A module containing various file utility functions
--
module Hakyll.Core.Util.File
    ( makeDirectories
    , getRecursiveContents
    , isFileObsolete
    ) where

import System.FilePath (normalise, takeDirectory, (</>))
import System.Time (ClockTime)
import Control.Monad (forM, filterM)
import System.Directory ( createDirectoryIfMissing, doesDirectoryExist
                        , doesFileExist, getModificationTime
                        , getDirectoryContents
                        )

-- | Given a path to a file, try to make the path writable by making
--   all directories on the path.
--
makeDirectories :: FilePath -> IO ()
makeDirectories = createDirectoryIfMissing True . takeDirectory

-- | Get all contents of a directory. Note that files starting with a dot (.)
--   will be ignored.
--
getRecursiveContents :: FilePath -> IO [FilePath]
getRecursiveContents topdir = do
    topdirExists <- doesDirectoryExist topdir
    if topdirExists
        then do names <- getDirectoryContents topdir
                let properNames = filter isProper names
                paths <- forM properNames $ \name -> do
                    let path = topdir </> name
                    isDirectory <- doesDirectoryExist path
                    if isDirectory
                        then getRecursiveContents path
                        else return [normalise path]
                return (concat paths)
        else return []
  where
    isProper = not . (== ".") . take 1

-- | Check if a timestamp is obsolete compared to the timestamps of a number of
-- files. When they are no files, it is never obsolete.
--
isObsolete :: ClockTime    -- ^ The time to check.
           -> [FilePath]   -- ^ Dependencies of the cached file.
           -> IO Bool
isObsolete _ [] = return False
isObsolete timeStamp depends = do
    depends' <- filterM doesFileExist depends
    dependsModified <- mapM getModificationTime depends'
    return (timeStamp < maximum dependsModified)

-- | Check if a file is obsolete, given it's dependencies. When the file does
-- not exist, it is always obsolete. Other wise, it is obsolete if any of it's
-- dependencies has a more recent modification time than the file.
--
isFileObsolete :: FilePath    -- ^ The cached file
               -> [FilePath]  -- ^ Dependencies of the cached file
               -> IO Bool
isFileObsolete file depends = do
    exists <- doesFileExist file
    if not exists
        then return True
        else do timeStamp <- getModificationTime file
                isObsolete timeStamp depends
