#!/usr/bin/perl -W

$debug = 0;

&main();

sub main {
   @devirq = ("eth0");
   foreach ( @ARGV ) {
      if ( $_ eq "debug") { 
         $debug = 1;
      } else {
         push(@devirq, $_);
      }
   }
   chomp(@devirq);

   &cpu_details();
   %dev_cpu = &interrupts(@devirq);

   foreach (keys %dev_cpu) { print $dev_cpu{$_} . "  " . $_ . "\n"; }
}

############################ SUBS ###########################

# pull cpu count and locality
sub cpu_details {
   my $core = 0;
   my %cpu_info; 
   my $cpu_count = 0;
   my %locality = ();

   open(INFILE, "/proc/cpuinfo");
   @pcpu_inf = <INFILE>;
   close INFILE;
   foreach (@pcpu_inf) {
      if ( $_ =~ /(processor|physical id|siblings|core id|cpu cores|apicid|initial apicid)\s+:\s+(\d+)/ ) {
         push(@{$cpu_info{$1}}, $2);
         if ( $1 eq "processor" ) { 
            $core = $2;
            $cpu_count++; 
         }
         if ( $1 eq "physical id" ) {
            push(@{$locality{$2}}, $core);
         }
      }
   }

   # debug out for comparing cpus
   if ( $debug == 1 ) {
      printf("%-20s", "");
      for ($i = 0; $i < $cpu_count; $i++ ) { printf("%6s", "CPU$i") }
      print "\n";

      # output core info chart
      foreach my $k (keys %cpu_info) {
         printf("%-20s", $k);
         foreach my $v (@{$cpu_info{$k}}) {
            printf("%6s", $v);
         }
         print "\n";
      }

      # output physical locality of cores
      foreach my $phys_cpu (keys %locality) {
         print "PHYS" . $phys_cpu . ": ";
         foreach my $cpu (@{$locality{$phys_cpu}}) {
            print " " . $cpu;
         }
         print "\n";
      }
   }

   return $cpu_count;
}

# find the cpu with the most interrupt traffic on IRQ
sub interrupts {
   my @devices = @_;
   my @dev_intr;
   my %cpu_irq_lock;

   open(INFILE, "/proc/interrupts");
   @interrupts = <INFILE>;
   close @interrupts;
   chomp(@interrupts);

   foreach my $dev (@devices) {
      foreach my $intr (@interrupts) {
         if ( $intr =~ /$dev/g ) {
            $intr =~ s/^\s+//g;
            $intr =~ s/\s+/  /g;
            if ($debug == 1) { print $intr . "\n"; }
            @dev_intr = split /\s+/, $intr;
         }

         my $hwm = 0;   # hi-water-mark
         my $hwc = 0;   # hi-water-cpu
         my $cpu_max = scalar @dev_intr - 2;

         for ( $i = 1; $i < $cpu_max; $i++ ) {
            if ( $dev_intr[$i] > $hwm ) { 
               $hwm = $dev_intr[$i];
               $cpu_irq_lock{$dev} = $i - 1;
            }
         }
      }
   }

   return %cpu_irq_lock;
}
