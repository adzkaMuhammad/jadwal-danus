-- Jalankan sekali di Supabase > SQL Editor. GANTI PIN '2026' dengan PIN operatormu.
create extension if not exists pgcrypto;

create table if not exists jadwal_danus(
  id uuid default gen_random_uuid() primary key,
  hari smallint not null check (hari between 0 and 6), -- 0=Minggu, 1=Senin ... 6=Sabtu
  shift_nama text not null,
  jam_mulai time not null,
  jam_selesai time not null,
  petugas text not null,
  catatan text default '',
  created_at timestamptz default now()
);
create table if not exists app_config(k text primary key, v text not null);
insert into app_config values('operator_pin','2026') on conflict (k) do update set v=excluded.v;

-- RLS aktif: publik hanya boleh BACA. Tulis hanya lewat fungsi yang cek PIN.
alter table jadwal_danus enable row level security;
alter table app_config enable row level security;
drop policy if exists "baca publik" on jadwal_danus;
create policy "baca publik" on jadwal_danus for select using (true);

create or replace function cek_pin(p_pin text) returns boolean
language sql security definer set search_path=public as
$$ select exists(select 1 from app_config where k='operator_pin' and v=p_pin) $$;

create or replace function simpan_shift(p_pin text,p_id uuid,p_hari smallint,p_nama text,p_mulai time,p_selesai time,p_petugas text,p_catatan text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not cek_pin(p_pin) then raise exception 'PIN salah'; end if;
  if p_id is null then
    insert into jadwal_danus(hari,shift_nama,jam_mulai,jam_selesai,petugas,catatan) values(p_hari,p_nama,p_mulai,p_selesai,p_petugas,p_catatan);
  else
    update jadwal_danus set hari=p_hari,shift_nama=p_nama,jam_mulai=p_mulai,jam_selesai=p_selesai,petugas=p_petugas,catatan=p_catatan where id=p_id;
  end if;
end $$;

create or replace function hapus_shift(p_pin text,p_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not cek_pin(p_pin) then raise exception 'PIN salah'; end if;
  delete from jadwal_danus where id=p_id;
end $$;

alter publication supabase_realtime add table jadwal_danus;
