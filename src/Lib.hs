{-# LANGUAGE OverloadedStrings #-}
module Lib
    ( setup
    ) where

import qualified Graphics.UI.Threepenny as UI
import Graphics.UI.Threepenny.Core

import Elements

import PhotoShake
import PhotoShake.ShakeConfig
import PhotoShake.Photographee

import System.FilePath

import Control.Monad 

import Control.Exception
import Development.Shake

import System.FSNotify hiding (defaultConfig)
import Control.Concurrent
import Data.IORef



setup :: Int -> String -> IO ()
setup port root = do
    config <- try $ toShakeConfig "config.cfg" :: IO (Either SomeException ShakeConfig)
    withManager $ \mgr -> do
            msgChan <- newChan
            _ <- watchDirChan
                    mgr
                    (root </> "config") --this is kind of wrong
                    (const True)
                    msgChan

            view <- case config of 
                    Right c -> do
                        conf <- newIORef c
                        return $ main conf msgChan
                    Left _ -> return missingConf

            startGUI
                defaultConfig { jsPort = Just port
                              } (view root)

            
receiveMsg :: Window -> IORef ShakeConfig -> EventChannel -> FilePath -> IO ()
receiveMsg w config events root = do
    messages <- getChanContents events
    forM_ messages $ \_ -> do 
        -- handle more gracefully pls
        config' <- try $ toShakeConfig "config.cfg" :: IO (Either SomeException ShakeConfig)
        _ <- case config' of 
                Right c -> modifyIORef config (\_ -> c)
                Left _ -> fail "ERROR"
        --nicess
        runUI w $ do

            conf <- liftIO $ readIORef config 
            let lol = _dumpConfig conf
            dumpConfig <- mkSection [ UI.p # set UI.text "dump mappe" 
                                    , readConf root lol 
                                    , mkConfPicker root lol
                                    ]

            let lol1 = _dagsdatoConfig conf
            dagsdatoConfig <- mkSection [ UI.p # set UI.text "dagsdato mappe"
                                        , readConf root lol1 
                                        , mkConfPicker root lol1
                                        ]

            let lol2 = _doneshootingConfig conf
            doneshootingConfig <- mkSection [ UI.p # set UI.text "doneshooting mappe"
                                            , readConf root lol2 
                                            , mkConfPicker root lol2
                                            ]

            let lol3 = _locationConfig conf
            locationConfig <- mkSection [ UI.p # set UI.text "lokationsFil"
                                        , readConf root lol3 --UI.p # set UI.text lol3
                                        , mkConfPicker2 root lol3
                                        ]

            ident <- liftIO $ newIORef ""
            (_, buildView) <- mkBuild conf root ident w

            (input, inputView) <- mkInput "elev nr:"
            on UI.keyup input $ \_ -> liftIO . writeIORef ident =<< get value input

            _ <- getBody w # set children [dumpConfig, dagsdatoConfig , doneshootingConfig, locationConfig, buildView, inputView]
            return ()


main :: IORef ShakeConfig -> EventChannel -> FilePath -> Window -> UI ()
main shakeConfig msgChan root w = do
    _ <- addStyleSheet w root "bulma.min.css"
    _ <- body w root shakeConfig msgChan
    return ()


body :: Window -> FilePath -> IORef ShakeConfig -> EventChannel -> UI ()
body w root config msgChan = do
    --section <- mkSection [ UI.p # set UI.text "Mangler måske config" ] 
    --
    -- extremum bads
    conf <- liftIO $ readIORef config 
    let lol = _dumpConfig conf
    dumpConfig <- mkSection [ UI.p # set UI.text "dump mappe" 
                            , readConf root lol 
                            , mkConfPicker root lol
                            ]

    let lol1 = _dagsdatoConfig conf
    dagsdatoConfig <- mkSection [ UI.p # set UI.text "dagsdato mappe"
                                , readConf root lol1 
                                , mkConfPicker root lol1
                                ]

    let lol2 = _doneshootingConfig conf
    doneshootingConfig <- mkSection [ UI.p # set UI.text "doneshooting mappe"
                                    , readConf root lol2 
                                    , mkConfPicker root lol2
                                    ]

    let lol3 = _locationConfig conf
    locationConfig <- mkSection [ UI.p # set UI.text "lokationsFil"
                                , readConf root lol3 --UI.p # set UI.text lol3
                                , mkConfPicker2 root lol3
                                ]

    ident <- liftIO $ newIORef ""
    (_, buildView) <- mkBuild conf root ident w

    (input, inputView) <- mkInput "elev nr:"
    on UI.keyup input $ \_ -> liftIO . writeIORef ident =<< get value input

    _ <- getBody w # set children [dumpConfig, dagsdatoConfig , doneshootingConfig, locationConfig, buildView, inputView]
    --bads
    msgChan' <- liftIO $ dupChan msgChan
    void $ liftIO $ forkIO $ receiveMsg w config msgChan' root
    
    return ()

readConf :: FilePath -> FilePath -> UI Element
readConf _ conf = do
    -- cant throw error
    x <- liftIO $ readFile conf
    UI.p # set UI.text x


mkConfPicker :: FilePath -> FilePath -> UI Element
mkConfPicker _ conf = do
    (_, view) <- mkFolderPicker "Vælg config folder" $ \folder -> do
        --this is full path will
        --that matter?
        writeFile conf $ "location = " ++ folder
        return ()
    return view

mkConfPicker2 :: FilePath -> FilePath -> UI Element
mkConfPicker2 _ conf = do
    (_, view) <- mkFilePicker "Vælg config fil" $ \file -> do
        --this is full path will
        --that matter?
        writeFile conf $ "location = " ++ file
        return ()
    return view


--mkBuild config root idd w err msg = do
mkBuild :: ShakeConfig -> FilePath -> IORef String -> Window -> UI (Element, Element)
mkBuild config root idd w = do
    (button, view) <- mkButton "Kør byg"
    callback <- ffiExport $ funci config root idd w 
    runFunction $ ffi "$(%1).on('click',%2)" button callback
    return (button, view)


{-
mkContent :: UI Element
mkContent = do
    mkColumns ["is-multiline"]
        [ mkColumn ["is-12"] [ element view ]
        , mkColumn ["is-12"] [ mkOutDirPicker ]
        , mkColumn ["is-8"] [ element inputView ]
        , mkColumn ["is-12"] [ element msgChanges ]
        , mkColumn ["is-12"] [ element view2 ]
        ]


mkOutDirPicker :: UI Element
mkOutDirPicker = do
    (_, view) <- mkFolderPicker "Vælg config folder"
    return view
-}

--setup :: IORef ShakeConfig -> EventChannel -> String -> Window -> UI ()
--setup config msgChan root w = do
  --  _ <- addStyleSheet w root "bulma.min.css"

  --  ident <- liftIO $ newIORef ""
--    (_, view) <- mkBuild config root ident w

--    (input, inputView) <- mkInput "elev nr:"
--    on UI.keyup input $ \_ -> liftIO . writeIORef ident =<< get value input

 --   _ <- getBody w #+ [ mkSection [ mkContent ]] 

    --return () 


-- kinda of bad
missingConf :: FilePath -> Window -> UI ()
missingConf root w = do
    _ <- addStyleSheet w root "bulma.min.css"
    section <- mkSection [UI.p # set UI.text "Mangler måske config"]
    _ <- getBody w #+ [element section] 
    return ()
    

--funci config root idd w err msg = do
funci :: ShakeConfig -> FilePath -> (IORef String) -> Window -> IO ()
funci config root idd _ = do
    --have to look this up from config
    idd2 <- readIORef idd
    let locationConfig = _locationConfig config
    locationFile <- getLocationFile locationConfig
    photographee <- findPhotographee (root </> locationFile) idd2
    _ <- try $ myShake config photographee :: IO (Either ShakeException ())
    --let ans = case build of
    --        Left _ -> element err # set text "Der skete en fejl"  
    --        Right _ -> element msg # set text "Byg færdigt"
    --_ <- runUI w ans
    return ()
