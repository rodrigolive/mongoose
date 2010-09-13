
use strict;
use warnings;



use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'MongoDB document to Moose object mapper',
  'AUTHOR' => 'Rodrigo de Oliveira <rodrigolive@gmail.com>',
  'BUILD_REQUIRES' => {},
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'Mongoose',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'Mongoose',
  'PREREQ_PM' => {
    'Carp' => '0',
    'List::Util' => '0',
    'Module::Pluggable' => '3.5',
    'MongoDB' => '0.35',
    'Moose' => '0.9',
    'MooseX::Role::Parameterized' => '0.16',
    'MooseX::Singleton' => '0',
    'Params::Coerce' => '0',
    'Scalar::Util' => '0'
  },
  'VERSION' => '0.03',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



