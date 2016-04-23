unit class Module::Toolkit;
use Module::Toolkit::Ecosystem;
use Module::Toolkit::Fetcher;
use Module::Toolkit::Installer;
use TAP;
use File::Find;

has $.ecosystem
    handles <project-list get-project get-dependencies>
    = Module::Toolkit::Ecosystem.new;

has $.fetcher
    = Module::Toolkit::Fetcher.new;

has $.installer
    handles <install>
    = Module::Toolkit::Installer.new;

has CompUnit::Repository @repos
    = <site home>.map({
        CompUnit::RepositoryRegistry.repository-for-name($_)
    });

method is-installed(Distribution $dist) {
    so any(@repos).resolve(
        CompUnit::DependencySpecification.new(
            :short-name($dist.name),
            :auth-matcher($dist.auth),
            :version-matcher($dist.version),
        )
    ) or so any(@repos).prefix.child('dist').child($dist.id).IO.e;
}

multi method fetch(Distribution $dist, IO::Path() $to) {
    my $url = $dist.source-url // $dist.support<source>;
    $.fetcher.fetch($url, $to);
}

multi method fetch(Str $url, IO::Path() $to) {
    $.fetcher.fetch($url, $to);
}

class Sink is IO::Handle {
    method print(|) { }
    method flush    { }
}

method test(IO::Path() $where, :$output = Sink.new) {
    temp $*CWD = chdir($where);
    return True unless $*CWD.child('t').IO.d;

    my @tests = find(dir => $*CWD.child('t'), name => /\.t$/).list».Str;
    my $handler = TAP::Harness::SourceHandler::Perl6.new(
        incdirs => [ $*CWD.child('lib') ]
    );

	my $run = TAP::Harness.new(
        handlers => $handler, :$output
    ).run(@tests);

    $run.result.get-status eq 'PASS'
}
