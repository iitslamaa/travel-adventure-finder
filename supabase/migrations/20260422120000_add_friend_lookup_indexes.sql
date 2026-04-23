create index if not exists friends_user_id_idx
on public.friends (user_id);

create index if not exists friends_friend_id_idx
on public.friends (friend_id);

create index if not exists friend_requests_receiver_status_idx
on public.friend_requests (receiver_id, status);
