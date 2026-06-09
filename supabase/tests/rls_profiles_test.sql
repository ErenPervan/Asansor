BEGIN;

-- pgTAP kullanarak test planini baslat
SELECT plan(3);

-- Test 1: Profiles tablosuna erisim kurallari
SELECT has_table('public', 'profiles', 'profiles tablosu public semasinda bulunmalidir');

-- Test 2: RLS'in acik olup olmadigini kontrol et
SELECT row_eq(
    $$ SELECT relrowsecurity FROM pg_class WHERE relname = 'profiles' $$,
    ROW(true),
    'Profiles tablosunda RLS aktif olmalidir'
);

-- Test 3: Kullanici sadece kendi profilini update edebilmeli kurali kontrolu
-- Bu sorgu, tablodaki policyleri kontrol ederek 'Users can update own profile' 
-- adli bir policy olup olmadigini test eder.
SELECT results_eq(
    $$ SELECT polname FROM pg_policy WHERE polname = 'Users can update own profile' $$,
    $$ VALUES ('Users can update own profile'::name) $$,
    'Kendi profilini guncelleme RLS kurali bulunmalidir'
);

SELECT finish();
ROLLBACK;
