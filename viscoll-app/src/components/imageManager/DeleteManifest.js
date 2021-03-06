import React, {Component} from 'react';
import Dialog from 'material-ui/Dialog';
import FlatButton from 'material-ui/FlatButton';
import RaisedButton from 'material-ui/RaisedButton';

/** Confirmation dialog to delete manifest */
export default class DeleteManifest extends Component {
  render() {
    const actions = [
      <FlatButton
        label="Cancel"
        primary={true}
        onClick={this.props.handleClose}
        keyboardFocused
      />,
      <RaisedButton
        label="Delete"
        onClick={()=>{this.props.handleClose(); this.props.deleteManifest()}}
        backgroundColor="#b53c3c"
        labelColor="#ffffff"    
      />,
    ];

    if (this.props.open) {
      return (
        <div>
          <Dialog
            title="Are you sure you want to delete the manifest?"
            actions={actions}
            modal={false}
            open={this.props.open}
            onRequestClose={this.props.handleClose}
          >
          </Dialog>
        </div>
      );
    } else {
      return <div></div>;
    }
  }
}