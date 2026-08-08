create policy "sessions_delete_own" on public.sessions
  for delete using ((select auth.uid()) = user_id);

grant delete on public.sessions to authenticated;
