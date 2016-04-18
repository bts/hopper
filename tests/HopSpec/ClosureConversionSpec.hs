{-# LANGUAGE OverloadedStrings #-}

module HopSpec.ClosureConversionSpec
  ( spec
  ) where

import Hopper.Internal.LoweredCore.ANF
import Hopper.Internal.LoweredCore.ClosureConversion (closureConvert)
import Hopper.Internal.LoweredCore.ClosureConvertedANF
import Hopper.Internal.Core.Literal
import Hopper.Internal.Type.Relevance
import Hopper.Internal.Type.BinderInfo
import Hopper.Utils.LocallyNameless

import Test.Hspec
import Test.Hspec.Expectations

import qualified Data.Vector as V
import qualified Data.Map as Map

spec :: Spec
spec =
  describe "Closure conversion" $ do
    let v0 = LocalVar $ LocalNamelessVar 0 $ BinderSlot 0
        v1 = LocalVar $ LocalNamelessVar 1 $ BinderSlot 0
        v2 = LocalVar $ LocalNamelessVar 2 $ BinderSlot 0
        add = GlobalVarSym $ GlobalSymbol "add"
        ten = LInteger 10
        twenty = LInteger 20
        dummyBI = BinderInfoData Omega () Nothing
        infos1 = V.singleton dummyBI
        infos2 = V.replicate 2 dummyBI
        arity1 = CodeArity 1
        -- arity2 = CodeArity 2
        emptyRegistry = SymbolRegistryCC Map.empty Map.empty Map.empty
        -- prim0 = PrimopIdGeneral "test"

    it "handles trivial closureless-code" $
      let anf = AnfLet infos1
                       (RhsAlloc $ AllocLit ten)
                       (AnfReturn $ V.singleton v0)
          ccd = LetNFCC infos1
                        (AllocRhsCC $ SharedLiteralCC ten)
                        (ReturnCC $ V.singleton v0)
          registry = emptyRegistry
      in closureConvert anf `shouldBe` (ccd, registry)

    it "converts closures" $
      let anf = AnfLet infos1
                       (RhsAlloc $ AllocLit ten)
                       (AnfLet infos1
                               (RhsAlloc $
                                 AllocLam infos1 $
                                   AnfLet infos1
                                          (RhsAlloc $ AllocLit twenty)
                                          (AnfReturn $ V.fromList [v0, v1, v2]))
                               (AnfReturn $ V.singleton v0))
          ccd = LetNFCC infos1
                        (AllocRhsCC $ SharedLiteralCC ten)
                        (LetNFCC infos1
                                 (AllocRhsCC $
                                   AllocateClosureCC (V.singleton v0)
                                                     arity1
                                                     (ClosureCodeId 0))
                                 (ReturnCC $ V.singleton v0))
          record = ClosureCodeRecordCC (EnvSize 1)
                                       infos1 -- for env
                                       arity1
                                       infos1 -- for args
                                       (LetNFCC infos1
                                                (AllocRhsCC $
                                                  SharedLiteralCC twenty)
                                                (ReturnCC $
                                                  V.fromList [ v0 -- local var
                                                             , v2 -- arg slot 0
                                                             , v1 -- env slot 0
                                                             ]))
          registry = SymbolRegistryCC Map.empty
                                      (Map.fromList [( ClosureCodeId 0
                                                     , record)])
                                      Map.empty
      in closureConvert anf `shouldBe` (ccd, registry)

    -- TODO: test ordering of >1 closure env var

    it "converts thunks" $
      let anf = AnfLet infos1
                       (RhsAlloc $ AllocLit ten)
                       (AnfLet infos1
                               (RhsAlloc $
                                 AllocThunk $
                                   AnfLet infos1
                                          (RhsAlloc $ AllocLit twenty)
                                          (AnfReturn $ V.fromList [v0, v1]))
                               (AnfReturn $ V.singleton v0))
          ccd = LetNFCC infos1
                        (AllocRhsCC $ SharedLiteralCC ten)
                        (LetNFCC infos1
                                 (AllocRhsCC $
                                   AllocateThunkCC (V.singleton v0)
                                                   (ThunkCodeId 0))
                                 (ReturnCC $ V.singleton v0))
          record = ThunkCodeRecordCC (EnvSize 1)
                                     infos1
                                     (LetNFCC infos1
                                              (AllocRhsCC $
                                                SharedLiteralCC twenty)
                                              (ReturnCC $
                                                V.fromList [ v0 -- local let
                                                           , v1 -- env slot 0
                                                           ]))
          registry = SymbolRegistryCC (Map.fromList [( ThunkCodeId 0
                                                     , record)])
                                      Map.empty
                                      Map.empty
      in closureConvert anf `shouldBe` (ccd, registry)

    -- TODO: test ordering of >1 thunk env var

    -- TODO: test nested closures/thunks; that only levels that need vars close
    --       over them.
