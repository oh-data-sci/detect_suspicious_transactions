
def make_pipeline():
    """create machine learning pipeline for hyperparameter searching.
   balance classes, fit parameters"""
    
    pipeline = Pipeline([('vec', vec),('clf', clf)])
    
    return pipeline

def evaluate(name, X_test, Y_test, estimator, class_names, other_estimators=None):
    """For and estimator serialize it, predict on held out test data.
    print Accuracy, Classification report, and Confution Matrix.
    """ 
    joblib.dump(estimator,"models/" + name+".pkl")

    preds = estimator.predict(X_test)
    accuracy = accuracy_score(Y_test, preds)
    print(name +"\n============\n")
    print()
    print("Accuracy: {}\n".format(accuracy_score(Y_test, preds)))
    
    display("Confusion Matrix")
    cm = confusion_matrix(Y_test, preds,labels=class_names)
    cm_normalized = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]*100
    
    df_normalized = pd.DataFrame(cm_normalized, index=class_names, columns = class_names)
    
    df = pd.DataFrame(cm, index=class_names, columns = class_names)
    df.loc["Predicted"] = cm.sum(axis=0)
    df["Actual"] = df.sum(axis=1)
    
    report = classification_report(Y_test, preds, output_dict=True)
    display("Classification Report")
    display(pd.DataFrame.from_dict(report).T)
    print()
    display(df)
    print()
    display(sns.heatmap(df_normalized, annot=True, fmt="g", cbar=False, vmin=0., vmax=100.))


def train_test_split(df):
    """Split dataframe columns 80/20 for train and test"""
    Y = df["labels"]
    X = df["text"]

    split = int(.8 *len(X))

    X_train = X[:split]
    Y_train = Y[:split]
    X_test = X[split:]
    Y_test = Y[split:]

    return X_train, Y_train, X_test, Y_test
    