#!/usr/bin/env perl
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use Fcntl qw(SEEK_SET LOCK_EX O_WRONLY O_CREAT O_EXCL);

@ARGV == 1 or die "Usage: $0 /path/to/dmcr.exe\nStop the game before patching. A .ac-linux.bak backup is created.\n";
my $path = $ARGV[0];
my $valid_ptr_va = 0x63ADF9;
my $final_hash = '6b12d1c94b22093ea345a0cecf3df31f517ecdfdafeb607a396d12757f3a141f';
my %supported = map { $_ => 1 } qw(
    54a63ca5a9dd8a8d63beb708a4ae82e12b73ac18b5b49155d881802e09877fd4
    456e60524d615def3f03ce073c641a3a506cf52a25b70bd563708f9733fa6025
    74b898794213c7a3d756e37437ee5273f396830939d1950542580f6a4bff435a
);
open my $fh, '+<:raw', $path or die "open $path: $!";
flock($fh, LOCK_EX) or die "lock $path: $!";
my $original = do { local $/; <$fh> };
my $hash = sha256_hex($original);
if ($hash eq $final_hash) {
    print "Already patched: $path\n";
    exit 0;
}
die "Unsupported dmcr.exe SHA-256: $hash; no files changed\n" unless $supported{$hash};
my $image = $original;
sub read_at {
    my ($off, $len) = @_;
    die "read outside executable" if $off < 0 || $off + $len > length($image);
    return substr($image, $off, $len);
}
sub write_at {
    my ($off, $buf) = @_;
    read_at($off, length($buf));
    substr($image, $off, length($buf)) = $buf;
}
sub rel32 {
    my ($target, $next_ip) = @_;
    return pack('l<', $target - $next_ip);
}
sub expect {
    my ($off, $hex) = @_;
    my $want = pack('H*', $hex);
    my $got = read_at($off, length($want));
    die sprintf("unexpected bytes at 0x%X: %s\n", $off, unpack('H*', $got))
        unless $got eq $want;
}
sub site_jump {
    my ($off, $va, $target) = @_;
    write_at($off, "\xE9" . rel32($target, $va + 5) . "\x90\x90");
}

# Reproduce the earlier null guard and unsigned index fix before extending
# them. This retains the historical instruction layout, including its tail.
write_at(0x86F3F, "\x76");
write_at(0x8BDB7, pack('H*', '85d274b88955dc8b45d889d18b14818d0c91894ddc'));
expect(0x8BD7E, '8b4dd40fbf5104');
expect(0x8BDB7, '85d274b88955dc');
expect(0x8BDE7, '8b45d80fbe0c02');
expect(0x86F3F, '76');

# Back the file-aligned tail of the first executable section. Its virtual
# size already covers this region, before the next section.
my $pe = unpack('V', read_at(0x3c, 4));
my $section0 = $pe + 24 + 0xE0;
expect($section0 + 16, '6cdf2600');
write_at($section0 + 16, pack('V', 0x26E000));
my $cave_off = 0x26E370;
my $cave_va = 0x66EF70;
expect($cave_off, '00' x 0x78);

# Primary AI object: validate the header, restore MOVSX, or safely return.
my $object_va = $cave_va;
my $object = '';
$object .= "\x8B\x4D\xD4";               # mov ecx,[ebp-2Ch]
$object .= "\x51";                       # preserve ecx
$object .= "\x6A\x06\x51";               # IsBadReadPtr(ecx,6)
$object .= "\xE8" . rel32($valid_ptr_va, $object_va + length($object) + 5);
$object .= "\x83\xC4\x08\x59";           # discard args; restore ecx
$object .= "\x85\xC0";
$object .= "\x0F\x84" . rel32(0x48C973, $object_va + length($object) + 6);
$object .= "\x0F\xBF\x51\x04";           # original movsx edx,word [ecx+4]
$object .= "\xE9" . rel32(0x48C985, $object_va + length($object) + 5);
die "object cave length changed" unless length($object) == 33;

# Main AI table: validate the exact indexed dword.
my $table_va = 0x66EFA0;
my $table = '';
$table .= "\x52";                        # preserve edx
$table .= "\x8B\x45\xD8\x8D\x04\x82";   # address edx + index*4
$table .= "\x6A\x04\x50";
$table .= "\xE8" . rel32($valid_ptr_va, $table_va + length($table) + 5);
$table .= "\x83\xC4\x08\x5A";
$table .= "\x85\xC0";
$table .= "\x0F\x84" . rel32(0x48C973, $table_va + length($table) + 6);
$table .= "\xE9" . rel32(0x48C9BE, $table_va + length($table) + 5);
die "table cave length changed" unless length($table) == 32;

# Optional byte table: unreadable data skips only its optional adjustment.
my $aux_va = 0x66EFC0;
my $aux = '';
$aux .= "\x52";
$aux .= "\x8B\x45\xD8\x8D\x04\x02";     # address edx + index
$aux .= "\x6A\x01\x50";
$aux .= "\xE8" . rel32($valid_ptr_va, $aux_va + length($aux) + 5);
$aux .= "\x83\xC4\x08\x5A";
$aux .= "\x85\xC0";
$aux .= "\x0F\x84" . rel32(0x48C9F6, $aux_va + length($aux) + 6);
$aux .= "\x8B\x45\xD8\x0F\xBE\x0C\x02"; # original instructions
$aux .= "\xE9" . rel32(0x48C9EE, $aux_va + length($aux) + 5);
die "aux cave length changed" unless length($aux) == 39;

write_at($cave_off, $object);
write_at(0x26E3A0, $table);
write_at(0x26E3C0, $aux);
site_jump(0x8BD7E, 0x48C97E, $object_va);
site_jump(0x8BDB7, 0x48C9B7, $table_va);
site_jump(0x8BDE7, 0x48C9E7, $aux_va);
die "Patched checksum mismatch; no files changed\n" unless sha256_hex($image) eq $final_hash;

# All checks complete before either backup creation or executable writes.
my $backup = "$path.ac-linux.bak";
sysopen my $bak, $backup, O_WRONLY | O_CREAT | O_EXCL, 0600
    or die "create backup $backup: $!";
binmode($bak, ':raw') or die "binmode backup: $!";
print {$bak} $original or die "write backup $backup: $!";
close $bak or die "close backup $backup: $!";
seek($fh, 0, SEEK_SET) or die "seek $path: $!";
print {$fh} $image or die "write $path: $!; restore $backup";
close $fh or die "close $path: $!; restore $backup";
print "Installed unsigned index fix and three AI pointer guards: $path\nSHA-256: $final_hash\nBackup: $backup\n";
