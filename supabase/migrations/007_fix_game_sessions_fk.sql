-- Fix foreign key constraint order: game_sessions is inserted before
-- the transaction is created in process_game_session, causing FK violations.
-- Making the constraint DEFERRABLE INITIALLY DEFERRED checks it at commit time.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'game_sessions_tx_id_fkey'
      AND conrelid = 'public.game_sessions'::regclass
  ) THEN
    ALTER TABLE public.game_sessions
      DROP CONSTRAINT game_sessions_tx_id_fkey;
  END IF;
END $$;

ALTER TABLE public.game_sessions
  ADD CONSTRAINT game_sessions_tx_id_fkey
  FOREIGN KEY (tx_id) REFERENCES public.transactions(tx_id)
  ON DELETE SET NULL
  DEFERRABLE INITIALLY DEFERRED;
