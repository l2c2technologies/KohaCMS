package Koha::Plugin::Com::L2C2Technologies::KohaCMS;

# Name    : KohaCMS - Koha plugin system package / perl module.
# Purpose : written to provide a WYSIWYG editor UI for Koha's
#           capability to add a simple CMS support.
#           http://wiki.koha-community.org/wiki/Koha_as_a_CMS

# Copyright (c) 2014 Indranil Das Gupta <indradg@gmail.com> /
#                    L2C2 Technologies, India.
# 
# Acknowledgement : The code in this .kpz package is partly based off
#                   modified NewsChannel.pm, koha-new.pl and koha-news.tt
#                   as present in Koha version 3.14.09.000;
#                   The KitchenSink tutorial by Kyle M. Hall / ByWater 
#                   Solutions was used for 'wire-framing' purpose.

# This file is part of a Koha Plugin System (.kpz) package - KohaCMS. 
#
# It works in conjunction with the Koha ILS's Plugin System.
#
# KohaCMS plugin is free software; you can redistribute it and/or modify 
# it under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# KohaCMS plugin is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License 
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Context;
use C4::Branch;
use C4::Members;
use C4::Auth;

our $VERSION = 1.2.1;

our $metadata = {
    name   => 'Koha CMS Editor',
    author => 'Indranil Das Gupta',
    description => 'Adds Koha\'s CMS feature with WYSIWYG edit option',
    date_authored   => '2014-08-10',
    date_updated    => '2014-08-15',
    minimum_version => '3.1406000',
    maximum_version => undef,
    version         => $VERSION,
};

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = $metadata;
    my $self = $class->SUPER::new($args);
    return $self;
}


sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
 
    my $op = $cgi->param('op');

    
    if ( $op ) {
        if ( $op eq 'add_form' ) {
	  $self->add_new_cms_page();
	} elsif ( $op eq 'edit_form' ) {
	  $self->edit_cms_page();
	} elsif ( $op eq 'save_page' ) {
	  $self->save_cms_page();	
	} elsif ( $op eq 'del_page' ) {
	  $self->del_cms_page();
	}
    } else {
	$self->show_cms_pages();
    } 
}

# CRUD handler - Insert and Update
sub save_cms_page {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    
    my $variable = $cgi->param('variable');
    my $value = $cgi->param('value');
    my $explanation = $cgi->param("explanation");
    my $type = $cgi->param('type');
    my $options	= $cgi->param('options');

    my $op_mode	= $cgi->param('mode');
    
    if ( $op_mode eq "insert" ) {
      my $newrecord = &add_page_new( $variable, $value, $options, $explanation, $type );
      print $cgi->redirect("/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::Com::L2C2Technologies::KohaCMS&amp;method=tool");
    } 
    elsif ( $op_mode eq "update" ) {
      my $updrecord = &upd_page_new( $variable, $value, $options, $explanation, $type );
      print $cgi->redirect("/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::Com::L2C2Technologies::KohaCMS&amp;method=tool");
      
    }
}

# CRUD handler - Deletion
sub del_cms_page {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my @ids = $cgi->param('variable');
    my $delrecords = &del_page_new( join ", ", map { "\'$_\'" } @ids );
    
    print $cgi->redirect("/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::Com::L2C2Technologies::KohaCMS&amp;method=tool");
}

# Function to display the UI for adding new pages
sub add_new_cms_page {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $id = $cgi->param("id");
    
    my ( $cms_newpage_uuid ) = &get_new_uuid( undef );
    
    my $template = $self->get_template( { file => 'kohacms_editor.tt' } );

    if ( $id ) {
      $template->param( mode => 'update' );
    } else {
      $template->param( mode => 'insert' );
    }
    
    $template->param( op => "add_form" );
    $template->param( cms_page_variable => $cms_newpage_uuid );
    $template->param( cms_page_options => "80|50" );
    $template->param( cms_page_type => "Textarea" );
    
    print $cgi->header();
    print $template->output();
}

# Function to display the UI for editing existing pages
sub edit_cms_page {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    
    my $id = $cgi->param("id");
    
    my ( $variable, $value, $explanation, $options, $type ) = &get_cms_entry ( $id );
    
    my $template = $self->get_template( { file => 'kohacms_editor.tt' } );
    
    if ( $id ) {
      $template->param( mode => 'update' );
    } else {
      $template->param( mode => 'insert' );
    }
    
    $template->param( op => "edit_form" );
    $template->param( cms_page_variable => $variable );
    $template->param( cms_page_value    => $value );
    $template->param( cms_page_options  => $options );
    $template->param( cms_page_type     => $type );
    $template->param( cms_page_explanation => $explanation );
    
    print $cgi->header();
    print $template->output();
}

sub get_cms_entry {
  my $variable  = $_[0];
  my $dbh = C4::Context->dbh;
  my $query = "SELECT * FROM systempreferences WHERE variable = ?";
  my $sth = $dbh->prepare($query);
  $sth->execute($variable);  
  my $record = $sth->fetchrow_hashref();
  my $cms_page_variable	= $record->{'variable'};
  my $cms_page_value		= $record->{'value'};
  my $cms_page_options	= $record->{'options'};
  my $cms_page_type		= $record->{'type'};
  my $cms_page_explanation 	= $record->{'explanation'};    
  $sth->finish;
  return ( $cms_page_variable, $cms_page_value, $cms_page_explanation, $cms_page_options, $cms_page_type );
}

# CRUD handler - Displays the UI for listing of existing pages.
sub show_cms_pages {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    
    my ( $cms_page_count, @cms_pages ) = &get_cms_entries( undef );
    
    my $template = $self->get_template( { file => 'kohacms.tt' } );

    print $cgi->header();
    
    $template->param( cms_page_count => $cms_page_count );
    $template->param( cms_pages => @cms_pages );
    $template->param( OPACBaseURL => C4::Context->preference('OPACBaseURL'));
    
    print $template->output();
}

sub get_cms_entries {
    my ($limit) = @_;
    my $dbh = C4::Context->dbh;
    my $query = "SELECT *, REPLACE( variable, 'page_', '' ) AS page_id FROM `systempreferences` WHERE `variable` LIKE 'page_%'";
    $query.= " ORDER BY variable ASC ";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my @cms_pages;
    my $count = 0;
    while (my $row = $sth->fetchrow_hashref) {
        if ((($limit) && ($count < $limit)) || (!$limit)) {
            push @cms_pages, $row;
        }
        $count++;
    }
    return ($count, \@cms_pages);
}

# DB function handler - INSERT
sub add_page_new {
    my ($variable, $value, $options, $explanation, $type) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("INSERT INTO systempreferences (variable, value, options, explanation, type) VALUES (?,?,?,?,?)");
    $sth->execute($variable, $value, $options, $explanation, $type);
    $sth->finish;
    return 1;
}

# DB function handler - UPDATE
sub upd_page_new {
    my ($variable, $value, $options, $explanation, $type) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("UPDATE systempreferences SET value = ?, options = ?, explanation = ?, type = ? WHERE variable = ?");
    $sth->execute($value, $options, $explanation, $type, $variable);
    $sth->finish;
    return 1;
}

# DB function handler - DELETE
sub del_page_new {
    my ($ids) = $_[0];
    if ($ids) {
        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare("DELETE FROM systempreferences WHERE variable IN ( $ids )");
        $sth->execute();
        $sth->finish;
        return 1;
    } else {
        return 0;
    }
}

# # Helper function to generate unique ids for page entries into the systempreferences table
sub get_new_uuid {
    my $dbh = C4::Context->dbh;
    my $query = "SELECT concat('page_', UUID_SHORT()) AS newpage_id";
    my $sth = $dbh->prepare($query);
    $sth->execute();   
    my $cms_page_uuid = '';
    while (my $row = $sth->fetchrow_hashref) {
	$cms_page_uuid = $row->{'newpage_id'};
    }
    $sth->finish;
    return ($cms_page_uuid);
}

# Generic uninstall routine - removes the plugin from plugin pages listing
sub uninstall() {
    my ( $self, $args ) = @_;
}
1;