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
import PhotoShake.ShakeError
import PhotoShake.Shooting

import System.FilePath

import Control.Monad 

import Control.Exception

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

            
receiveMsg :: Window -> FilePath -> IORef ShakeConfig -> EventChannel -> IO ()
receiveMsg w root config events = do
    messages <- getChanContents events
    forM_ messages $ \_ -> do 
        -- handle more gracefully pls
        config' <- try $ toShakeConfig "config.cfg" :: IO (Either SomeException ShakeConfig)
        _ <- case config' of 
                Right c -> modifyIORef config (\_ -> c)
                Left _ -> fail "ERROR"
        --nicess
        runUI w (body w root config events)


main :: IORef ShakeConfig -> EventChannel -> FilePath -> Window -> UI ()
main shakeConfig msgChan root w = do
    _ <- addStyleSheet w root "bulma.min.css"
    _ <- body w root shakeConfig msgChan
    return ()


-- improve me

lol :: [Shooting]
lol = [Normal, Omfoto]

shootingSection :: FilePath -> Shooting -> UI Element
shootingSection _ _ = mkSection [ mkLabel "Shooting Type"
                               --               , readConf2 root shootingType
                                              , mkRadioGroup lol
                                              ]


mkRadio :: Shooting -> UI Element
mkRadio x = do
    radio <- case x of
            Omfoto -> UI.input # set UI.type_ "radio" # set UI.name "foobar" # set UI.html (show x)
            Normal -> UI.input # set UI.type_ "radio" # set UI.name "foobar" # set UI.html (show x) # set (UI.attr "checked") "true"
    view <- UI.label #. "radio" #+ [ element radio, string (show x)]
    return view


mkRadioGroup :: [Shooting] -> UI Element
mkRadioGroup xs = do
    view <- UI.div #. "control" #+ (fmap (mkRadio) xs)
    return view




dumpSection :: FilePath -> FilePath -> UI Element
dumpSection root dumpPath = mkSection [ mkLabel "Dump mappe" 
                                      , readConf root dumpPath 
                                      , mkConfPicker root dumpPath
                                      ]

dagsdatoSection :: FilePath -> FilePath -> UI Element
dagsdatoSection root dagsdatoPath = mkSection [ mkLabel "Dagsdato mappe"
                                              , readConf root dagsdatoPath
                                              , mkConfPicker root dagsdatoPath
                                              ]


locationsFilSection :: FilePath -> FilePath -> UI Element
locationsFilSection root locationFilePath = 
    mkSection [ mkLabel "Lokations Fil"
              , readConf root locationFilePath
              , mkConfPicker2 root locationFilePath
              ]

doneshootingSection :: FilePath -> FilePath -> UI Element
doneshootingSection root doneshootingPath = 
    mkSection [ mkLabel "Doneshooting mappe"
              , readConf root doneshootingPath
              , mkConfPicker2 root doneshootingPath
              ]


body :: Window -> FilePath -> IORef ShakeConfig -> EventChannel -> UI ()
body w root config msgChan = do
    --section <- mkSection [ UI.p # set UI.text "Mangler måske config" ] 
    --
    -- extremum bads
    conf <- liftIO $ readIORef config 

    shootingConfig <- shootingSection root (_shootingType conf)

    dumpConfig <- dumpSection root (_dumpConfig conf)

    dagsdatoConfig <- dagsdatoSection root (_dagsdatoConfig conf)

    doneshootingConfig <- doneshootingSection root (_doneshootingConfig conf)

    locationConfig <- locationsFilSection root (_locationConfig conf)

    err <- UI.p 
    msg <- UI.p 
    ident <- liftIO $ newIORef ""
    (_, buildView) <- mkBuild conf root ident w err msg

    (input, inputView) <- mkInput "Elev nr:"
    on UI.keyup input $ \_ -> liftIO . writeIORef ident =<< get value input

    inputView2 <- mkSection $ 
                    [ mkColumns ["is-multiline"]
                        [ mkColumn ["is-4"] [element inputView]
                        , mkColumn ["is-12"] [element buildView]
                        , mkColumn ["is-12"] [element err, element msg] 
                        ]
                    ]

    _ <- getBody w # set children [shootingConfig, dumpConfig, dagsdatoConfig , doneshootingConfig, locationConfig, inputView2]
    --bads
    msgChan' <- liftIO $ dupChan msgChan
    void $ liftIO $ forkIO $ receiveMsg w root config msgChan'
    
    return ()


readConf :: FilePath -> FilePath -> UI Element
readConf _ conf = do
    -- cant throw error
    x <- liftIO $ readFile conf
    UI.p # set UI.text x

--readConf2 :: FilePath -> Shooting -> UI Element
--readConf2 _ x = do
--    UI.p # set UI.text (show x)


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
mkBuild :: ShakeConfig -> FilePath -> IORef String -> Window -> Element -> Element -> UI (Element, Element)
mkBuild config root idd w err msg = do
    (button, view) <- mkButton "Kør byg"
    callback <- ffiExport $ funci config root idd w err msg
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
funci :: ShakeConfig -> FilePath -> (IORef String) -> Window -> Element -> Element -> IO ()
funci config root idd w err msg = do
    --have to look this up from config
    idd2 <- readIORef idd
    let locationConfig = _locationConfig config
    locationFile <- getLocationFile locationConfig
    -- kinda bad here
    find <- try $ findPhotographee (root </> locationFile) idd2 :: IO (Either ShakeError Photographee)
    case find of
            Left errMsg -> do
                    _ <- runUI w $ element err # set text (show errMsg)
                    return ()
            Right photographee -> do
                    build <- try $ myShake config photographee :: IO (Either ShakeError ())
                    let ans = case build of
                            Left errMsg -> element err # set text (show errMsg)
                            Right _ -> element msg # set text "Byg færdigt"
                    -- reset
                    _ <- runUI w (element err # set text "")
                    _ <- runUI w (element msg # set text "")
                    _ <- runUI w ans
                    return ()
