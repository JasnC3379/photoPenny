{-# LANGUAGE OverloadedStrings #-}
module Lib
    ( someFunc
    ) where

import qualified Graphics.UI.Threepenny as UI
import Graphics.UI.Threepenny.Core

import Control.Monad

import System.Exit
import System.Process

import Debug.Trace


mkButton :: String -> String -> UI (Element, Element)
mkButton title id = do
    button <- UI.button #. "button" # set UI.id_ id #+ [string title]
    view <- UI.p #+ [element button]
    return (button, view)


setup :: Window -> UI ()
setup w = do
    (button, view) <- mkButton "Run build" "thisId"

    msg <- UI.span # set UI.text "Some text"

    getBody w #+ [element view, element msg]
    
    body <- getBody w
     
    onElementId "thisId" "click" $ do
        element msg # set text "Clicked"


onElementId :: String -> String -> UI void -> UI ()
onElementId elid event handler = do
    window   <- askWindow
    exported <- ffiExport $ do
        (exitcode, stdout, stderr) <- myProcess
        runUI window handler
        return ()
    runFunction $ ffi "$(%1).on(%2,%3)" ("#"++elid) event exported


myProcess :: IO (ExitCode, String, String)
myProcess = 
    readCreateProcessWithExitCode 
        ((shell "photoShake-exe") 
            {cwd = Just "/home/magnus/Documents/projects/photoShake/" }) ""


someFunc :: IO ()
someFunc =
    startGUI
        defaultConfig { jsCustomHTML = Just "index.html"
                      , jsStatic = Just "static" } 
        setup
