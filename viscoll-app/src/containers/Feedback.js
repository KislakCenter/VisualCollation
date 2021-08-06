import React, { Component } from 'react';
import { connect } from "react-redux";
import Dialog from 'material-ui/Dialog';
import FlatButton from 'material-ui/FlatButton';
import RaisedButton from 'material-ui/RaisedButton';
import TextField from 'material-ui/TextField';
import ClientJS from 'clientjs';
import { exportProjectBeforeFeedback } from "../actions/backend/projectActions";
import { sendFeedback } from "../actions/backend/userActions";

/** Feedback form that sends an email to admin for each feedback */
class Feedback extends Component {
  constructor(props) {
    super(props);
    this.state = {
      feedbackOpen: false,
      creditsOpen: false,
      title: "",
      feedback: "",
    }
  }
  handleOpen = (type) => {
    if (type === "feedback") {
      this.setState({ feedbackOpen: true });
    } else if (type === "credits") {
      this.setState({ creditsOpen: true });
    }
  }
  handleClose = (type) => {
    if (type === "feedback") {
      this.setState({
        feedbackOpen: false,
        title: "",
        feedback: "",
      });} else if (type === "credits") {
      this.setState({ creditsOpen: false });
    }
    this.props.togglePopUp(false);
  }
  onChange = (type, value) => {
    this.setState({ [type]: value });
  }
  submit = () => {
    let feedback = this.state.feedback;
    let browserInformation;
    try {
      const client = new ClientJS();
      const result = client.getResult();
      browserInformation = JSON.stringify(result);
    } catch (e) { }
    this.props.sendFeedback(this.state.title, feedback, browserInformation, this.props.projectID);
    this.handleClose();
  }
  render() {
    const feedbackActions = [
      <FlatButton
        label="Cancel"
        primary={true}
        onClick={() => this.handleClose("feedback")}
      />,
      <RaisedButton
        label="Submit"
        primary={true}
        disabled={this.state.title.length === 0 || this.state.feedback.length === 0}
        onClick={() => this.submit()}
      />,
    ];
    const creditsActions = [
      <FlatButton
          label="Close"
          primary={true}
          onClick={() => this.handleClose("credits")}
      />
    ]
    return (
      <div>
        <div className="feedback">
          <FlatButton
            label="Feedback"
            labelStyle={{ color: "#ffffff" }}
            onClick={() => { this.handleOpen("feedback"); this.props.togglePopUp(true) }}
            backgroundColor="rgba(82, 108, 145, 0.2)"
            tabIndex={this.props.tabIndex}
          />
          <FlatButton
              label="About"
              labelStyle={{ color: "#ffffff" }}
              onClick={() => { this.handleOpen("credits"); this.props.togglePopUp(true) }}
              backgroundColor="rgba(82, 108, 145, 0.2)"
              tabIndex={this.props.tabIndex}
          />
        </div>
        <Dialog
          title="Share your feedback"
          actions={feedbackActions}
          modal={true}
          open={this.state.feedbackOpen}
          paperClassName="feedbackDialog"
          contentStyle={{ width: "450px" }}
        >
          <p>Bug? Suggestions? Let us know!</p>
          <div>
            <div id="feedbackTitle" className="label">
              Title
            </div>
            <div className="input">
              <TextField
                name="title"
                aria-labelledby="feedbackTitle"
                value={this.state.title}
                onChange={(e, v) => this.onChange("title", v)}
                autoFocus
              />
            </div>
          </div>
          <div>
            <div id="feedbackContent" className="label">
              Feedback
            </div>
            <div className="input">
              <textarea
                name="feedback"
                aria-labelledby="feedbackContent"
                value={this.state.feedback}
                onChange={(e) => this.onChange("feedback", e.target.value)}
                rows={5}
              />
            </div>
          </div>
        </Dialog>
        <Dialog
            title="Credits"
            actions={creditsActions}
            modal={true}
            open={this.state.creditsOpen}
            paperClassName="feedbackDialog"
            contentStyle={{ width: "1000px" }}
        >
          <p>
            VCEditor is a tool for building and visualizing the physical structure of manuscripts using the data model
            provided by <a href="https://viscoll.org/" target="_blank">VisColl</a>: Modeling and Visualizing the
            Physical Construction of Codex Manuscripts, a project
            co-directed by Alberto Campagnolo and Dot Porter.
          </p>

          <p>
            VCEditor is a continuation of development of <a
              href="https://github.com/utlib/VisualCollation" target="_blank">VisCodex</a>,
            developed by the Old Books New Science lab at the University of Toronto, directed by Dr Alexandra Gillespie.
            The VisCodex development team consisted of Monica Ung, Janarthenan Rajakumar, and Rachel Di Cresce.
          </p>

          <p>
            For <a href="https://github.com/KislakCenter/VisualCollation" target="_blank">VCEditor</a> we have made several
            modification, particularly to the back end, to ensure that the output
            validates to the most recent version of the VisColl data model. Development of the XSLT pipelines for
            VCEditor, called <a href="https://github.com/gremid/idrovora" target="_blank">Idrovora</a>, was done by Gregor Middel, and
            primary development of VCEditor was done by Patrick Perkins.
          </p>

          <p>
            Supervision of all development was provided by Doug Emery, and organizational support was provided by Lynn
            Ransom. We would like to thank the Schoenberg Institute for Manuscript Studies and the University of
            Pennsylvania Libraries for their continued support of the project.
          </p>
        </Dialog>
      </div>
    );
  }
}
const mapStateToProps = (state) => {
  return {
    userID: state.user.id,
    projectID: state.active.project ? state.active.project.id : null
  };
};

const mapDispatchToProps = (dispatch) => {
  return {
    sendFeedback: (title, message, browserInformation, projectID) => {
      if (projectID) {
        dispatch(exportProjectBeforeFeedback(projectID, "json"))
          .then((action) => {
            if (action.type === "EXPORT_SUCCESS") {
              const project = JSON.stringify(action.payload);
              dispatch(sendFeedback(title, message, browserInformation, project));
            }
          })
      } else {
        dispatch(sendFeedback(title, message, browserInformation));
      }
    }
  };
};

export default connect(mapStateToProps, mapDispatchToProps)(Feedback);
